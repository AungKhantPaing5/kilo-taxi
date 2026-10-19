import SwiftUI
import CoreLocation
import Security

private enum SecureSession {
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "uk.payapi.kilotaxi", kSecAttrAccount as String: "session"]
    static func read() -> String {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &value) == errSecSuccess, let data = value as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ value: String) {
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var q = query; q[kSecValueData as String] = Data(value.utf8); q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor final class DriverModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var origin = UserDefaults.standard.string(forKey: "server") ?? "https://thai1.payapi.uk"
    @Published var username = ""
    @Published var password = ""
    @Published var loggedIn = false
    @Published var busy = false
    @Published var tracking = false
    @Published var userName = ""
    @Published var status = "Login ဝင်ပြီး ခရီးစပါ။"
    @Published var accuracy = "—"
    @Published var meter: [String: Any] = [:]
    @Published var authorized = false
    @Published var clock = Date()
    private var receivedAt = Date()
    private var cookie = SecureSession.read()
    private let gps = CLLocationManager()
    private var fix: CLLocation?
    private var timer: Timer?
    private var lastSync = Date.distantPast
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 18
        return URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }()
    override init() {
        super.init(); gps.delegate = self; gps.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        gps.distanceFilter = kCLDistanceFilterNone; gps.activityType = .automotiveNavigation
        gps.pausesLocationUpdatesAutomatically = false; gps.showsBackgroundLocationIndicator = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.clock = Date(); await self?.heartbeat() } }
    }
    var active: Bool { !meter.isEmpty && state != "finished" }
    var state: String { meter["state"] as? String ?? "OFF" }
    var waiting: Bool { meter["waitingEnabled"] as? Bool ?? false }
    var shouldTrack: Bool { active && (state != "paused" || meter["autoResume"] as? Bool == true) }
    var displayedWaitingSeconds: Int { Int(number("waitingSeconds") + (tracking && waiting && state != "paused" ? min(30, max(0, clock.timeIntervalSince(receivedAt))) : 0)) }
    func number(_ key: String) -> Double { (meter[key] as? NSNumber)?.doubleValue ?? 0 }
    private func failure(_ message: String) -> NSError { NSError(domain: "KiloTaxi", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    private func validatedOrigin(_ input: String) throws -> String {
        guard let c = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)), c.scheme == "https", c.host != nil, c.user == nil, c.password == nil, c.query == nil, c.fragment == nil, c.path.isEmpty || c.path == "/" else { throw failure("HTTPS server origin သာဖြည့်ပါ။") }
        var clean = c; clean.path = ""; return clean.string!
    }
    private func api(_ path: String, _ body: [String: Any]? = nil) async throws -> [String: Any] {
        guard let url = URL(string: origin + "/api/taxi/" + path) else { throw failure("Invalid server URL") }
        var request = URLRequest(url: url); request.setValue(origin, forHTTPHeaderField: "Origin")
        request.setValue(cookie, forHTTPHeaderField: "Cookie"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpMethod = "POST"; request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (bytes, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw failure("Server မရပါ။") }
        let data = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any] ?? [:]
        if http.statusCode == 401 { cookie = ""; SecureSession.save(""); stopGPS(); loggedIn = false; throw failure("Session သက်တမ်းကုန်ပါပြီ။ Login ပြန်ဝင်ပါ။") }
        guard (200...299).contains(http.statusCode) else { throw failure(data["error"] as? String ?? "Server error \(http.statusCode)") }
        if let header = http.value(forHTTPHeaderField: "Set-Cookie") { cookie = String(header.split(separator: ";", maxSplits: 1)[0]); SecureSession.save(cookie) }
        return data
    }
    private func apply(_ data: [String: Any]) { receivedAt = Date(); meter = data["meter"] as? [String: Any] ?? [:]; if !shouldTrack { stopGPS() } }
    func login() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { origin = try validatedOrigin(origin); UserDefaults.standard.set(origin, forKey: "server"); cookie = ""; SecureSession.save("")
            let user = try await api("login", ["username": username, "password": password]); password = ""
            guard let permissions = user["permissions"] as? [String], permissions.contains("calculate"), permissions.contains("save_trips") else { throw failure("ဒီ account မှာ မီတာသုံးခွင့် မရှိပါ။") }
            UserDefaults.standard.set(origin, forKey: "server"); userName = user["name"] as? String ?? username
            apply(try await api("meter")); loggedIn = true; status = "ခရီးစမယ် / GPS ဆက်ချိတ်မယ် ကိုနှိပ်ပါ။"
        } catch { status = error.localizedDescription }
    }
    func restore() async {
        guard !cookie.isEmpty, !busy, !loggedIn else { return }; busy = true; defer { busy = false }
        do { let user = try await api("me"); userName = user["name"] as? String ?? "Driver"; apply(try await api("meter")); loggedIn = true; status = "လက်ရှိခရီးဆက်ရန် GPS ဆက်ချိတ်မယ် ကိုနှိပ်ပါ။" } catch { status = error.localizedDescription }
    }
    func requestPermission() {
        guard CLLocationManager.locationServicesEnabled() else { status = "ဖုန်း Location Services ကို ဖွင့်ပါ။"; return }
        switch gps.authorizationStatus {
        case .notDetermined: gps.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: gps.requestAlwaysAuthorization(); status = "While Using ခွင့်ပြုထားပါတယ်။ ခရီးစချိန် background GPS ကို စတင်ပါမယ်။"
        case .authorizedAlways: status = "Location permission ရရှိပြီးပါပြီ။"
        default: status = "Settings မှာ Kilo Taxi Location ကို ခွင့်ပြုပေးပါ။"
        }
    }
    private func startGPS() {
        guard [.authorizedWhenInUse, .authorizedAlways].contains(gps.authorizationStatus) else { requestPermission(); return }
        gps.allowsBackgroundLocationUpdates = true; gps.startUpdatingLocation(); tracking = true
    }
    private func stopGPS() { gps.stopUpdatingLocation(); gps.allowsBackgroundLocationUpdates = false; tracking = false; fix = nil }
    func action(_ type: String) async {
        guard !busy else { return }
        if ["start", "resume", "waiting_on", "waiting_off"].contains(type) && ![.authorizedWhenInUse, .authorizedAlways].contains(gps.authorizationStatus) { requestPermission(); return }
        busy = true; defer { busy = false }
        do {
            if type == "start" { if active { apply(try await api("meter")) } else { apply(try await api("meter/start", [:])) } }
            else if let id = meter["id"] as? String { apply(try await api("meter/" + id, ["type": type])) }
            if shouldTrack { startGPS() } else { stopGPS() }; status = "မီတာ sync ဖြစ်နေပါတယ်။"
        } catch { status = error.localizedDescription }
    }
    func heartbeat() async {
        guard tracking, shouldTrack, !busy, Date().timeIntervalSince(lastSync) >= 5, let id = meter["id"] as? String else { return }
        busy = true; lastSync = Date()
        let token = UIApplication.shared.beginBackgroundTask(withName: "MeterSync", expirationHandler: nil)
        defer { busy = false; if token != .invalid { UIApplication.shared.endBackgroundTask(token) } }
        do {
            var body: [String: Any] = ["type": "heartbeat"]
            if let f = fix, abs(f.timestamp.timeIntervalSinceNow) <= 15, f.horizontalAccuracy >= 0 {
                body["fix"] = ["lat": f.coordinate.latitude, "lng": f.coordinate.longitude, "accuracy": f.horizontalAccuracy, "speed": f.speed >= 0 ? f.speed as Any : NSNull(), "timestamp": f.timestamp.timeIntervalSince1970 * 1000]
            }
            apply(try await api("meter/" + id, body)); status = "GPS / Server sync ဖြစ်နေပါတယ်။"
        } catch { status = "Sync မရပါ — " + error.localizedDescription }
    }
    func logout() async { guard !active, !busy else { return }; busy = true; defer { busy = false }; _ = try? await api("logout", [:]); cookie = ""; SecureSession.save(""); stopGPS(); loggedIn = false }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { authorized = [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus); if !authorized { stopGPS(); status = "GPS ခွင့်ပြုချက်ကို စစ်ပါ။" } }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { guard let location = locations.last, fix == nil || location.timestamp > fix!.timestamp else { return }; fix = location; accuracy = "\(Int(location.horizontalAccuracy)) m"; Task { await heartbeat() } }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { status = "GPS: " + error.localizedDescription }
}

@main struct KiloTaxiApp: App {
    @StateObject private var model = DriverModel()
    var body: some Scene { WindowGroup { DriverView(model: model) } }
}
struct DriverView: View {
    @ObservedObject var model: DriverModel
    @State private var confirmFinish = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("KILO TAXI · DRIVER").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    if !model.loggedIn {
                        Text("အကောင့်ဝင်ရန်").font(.largeTitle.bold())
                        TextField("HTTPS server", text: $model.origin).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        TextField("Username", text: $model.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Password", text: $model.password)
                        Button("ဝင်မယ်") { Task { await model.login() } }.disabled(model.busy)
                    } else {
                        Text(model.userName).font(.title2.bold())
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(format: "%.3f km", model.number("km"))).font(.system(size: 42, weight: .bold))
                            Text(String(format: "%.0f ကျပ်", model.number("total"))).font(.largeTitle.bold())
                            Text("စောင့်ချိန် \(model.displayedWaitingSeconds) စက္ကန့်")
                            Text(model.state.uppercased()).font(.caption.bold())
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.08, green: 0.26, blue: 0.20)).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 22))
                        Text("ခရီးစချိန် GPS ကို screen ပိတ်ထားချိန်ပါ သုံးပါမယ်။ Waiting ပထမ 10 မိနစ် အခမဲ့။ ခရီးဆုံး / Pause မှာ GPS ရပ်ပါမယ်။")
                        Button("GPS permission ခွင့်ပြုရန်") { model.requestPermission() }
                        Button(model.active ? "GPS ဆက်ချိတ်မယ်" : "ခရီးစမယ်") { Task { await model.action("start") } }.disabled(model.busy || model.tracking)
                        Button(model.waiting ? "Waiting OFF" : "Waiting ON") { Task { await model.action(model.waiting ? "waiting_off" : "waiting_on") } }.disabled(model.busy || !model.active || model.state == "paused")
                        HStack {
                            Button("ခေတ္တရပ်ရန်") { Task { await model.action("pause") } }.disabled(model.busy || !model.active || model.state == "paused")
                            Button("ပြန်စရန်") { Task { await model.action("resume") } }.disabled(model.busy || model.state != "paused")
                        }
                        Button("ခရီးဆုံး · သိမ်းမယ်", role: .destructive) { confirmFinish = true }.disabled(model.busy || !model.active)
                        Text("GPS accuracy: \(model.accuracy) · \(model.tracking ? "Background GPS ON" : "GPS OFF")").font(.caption)
                        if let url = URL(string: model.origin + "/history") { Link("History / Admin website", destination: url) }
                        Button("Logout") { Task { await model.logout() } }.disabled(model.busy || model.active)
                    }
                    Text(model.status).font(.callout).foregroundStyle(.secondary)
                    Text("Internet / GPS ပြတ်ချိန်က km ကို ခန့်မှန်းမဖြည့်ပါ။ App ကို Force Quit လုပ်ထားရင် tracking မဆက်နိုင်ပါ။").font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }.textFieldStyle(.roundedBorder).buttonStyle(.borderedProminent).tint(Color(red: 0.10, green: 0.36, blue: 0.27))
                .navigationTitle("Kilo Taxi")
                .confirmationDialog("ခရီးကို အဆုံးသတ်ပြီး history ထဲ သိမ်းမလား?", isPresented: $confirmFinish) { Button("ခရီးဆုံး · သိမ်းမယ်", role: .destructive) { Task { await model.action("finish") } } }
                .task { await model.restore() }
        }
    }
}
