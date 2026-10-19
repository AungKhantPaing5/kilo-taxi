package uk.payapi.kilotaxi;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONObject;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

final class Engine {
    static final ExecutorService queue = Executors.newSingleThreadExecutor();
    static volatile JSONObject meter = null;
    static volatile JSONObject user = null;
    static volatile String status = "GPS tracking မစရသေးပါ။";
    static volatile String accuracy = "—";
    static volatile boolean tracking = false;
    static volatile long receivedAt = 0;
    static SharedPreferences prefs;
    static void init(Context context) { if(prefs == null) prefs=context.getApplicationContext().getSharedPreferences("session",Context.MODE_PRIVATE); }
    static String origin() { return prefs.getString("origin","https://thai1.payapi.uk"); }
    static String normalize(String value) throws Exception {
        URI uri=new URI(value.trim());
        if(!"https".equals(uri.getScheme())||uri.getHost()==null||uri.getUserInfo()!=null||uri.getQuery()!=null||uri.getFragment()!=null||!(uri.getPath()==null||uri.getPath().isEmpty()||uri.getPath().equals("/"))) throw new Exception("HTTPS server origin သာဖြည့်ပါ။");
        return "https://"+uri.getRawAuthority();
    }
    static JSONObject call(String path,JSONObject body) throws Exception {
        HttpURLConnection connection=(HttpURLConnection)new URI(origin()+"/api/taxi/"+path).toURL().openConnection();
        connection.setInstanceFollowRedirects(false);connection.setConnectTimeout(10000);connection.setReadTimeout(10000);
        connection.setRequestProperty("Origin",origin());connection.setRequestProperty("Content-Type","application/json");
        connection.setRequestProperty("Cookie",prefs.getString("cookie",""));
        try {
            if(body!=null){connection.setRequestMethod("POST");connection.setDoOutput(true);try(var out=connection.getOutputStream()){out.write(body.toString().getBytes(StandardCharsets.UTF_8));}}
            int code=connection.getResponseCode();
            var stream=code<400?connection.getInputStream():connection.getErrorStream();
            String text="{}";if(stream!=null){try(var bytes=new java.io.ByteArrayOutputStream()){byte[] buffer=new byte[4096];int n;while((n=stream.read(buffer))!=-1)bytes.write(buffer,0,n);text=bytes.toString(StandardCharsets.UTF_8.name());}finally{stream.close();}}
            JSONObject data=new JSONObject(text);
            if(code==401){prefs.edit().remove("cookie").apply();throw new AuthError();}
            if(code<200||code>=300)throw new Exception(data.optString("error","Server error "+code));
            String cookie=connection.getHeaderField("Set-Cookie");if(cookie!=null)prefs.edit().putString("cookie",cookie.split(";",2)[0]).apply();
            return data;
        } finally {connection.disconnect();}
    }
    static void apply(JSONObject data) {meter=data.optJSONObject("meter");receivedAt=System.currentTimeMillis();}
    static boolean active(){return meter!=null&&!"finished".equals(meter.optString("state"));}
    static boolean shouldTrack(){return active()&&(!"paused".equals(meter.optString("state"))||meter.optBoolean("autoResume"));}
    static class AuthError extends Exception {AuthError(){super("Session သက်တမ်းကုန်ပါပြီ။ Login ပြန်ဝင်ပါ။");}}
}
