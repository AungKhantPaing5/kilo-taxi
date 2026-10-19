package uk.payapi.kilotaxi;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.location.*;
import android.os.*;
import org.json.JSONObject;
import java.util.Locale;

public class TrackingService extends Service implements LocationListener {
    private final Handler handler=new Handler(Looper.getMainLooper());
    private LocationManager locations;
    private volatile Location latest;
    private volatile boolean busy=false;
    private PowerManager.WakeLock wake;
    private final Runnable tick=new Runnable(){public void run(){if(!Engine.tracking)return;if(wake!=null&&!wake.isHeld())wake.acquire(600000);if(!busy){busy=true;Engine.queue.execute(()->{try{if(Engine.shouldTrack()){JSONObject body=new JSONObject().put("type","heartbeat");Location fix=latest;if(fix!=null&&Math.abs(System.currentTimeMillis()-fix.getTime())<=15000){JSONObject point=new JSONObject().put("lat",fix.getLatitude()).put("lng",fix.getLongitude()).put("accuracy",fix.getAccuracy()).put("timestamp",fix.getTime());point.put("speed",fix.hasSpeed()?fix.getSpeed():JSONObject.NULL);body.put("fix",point);}Engine.apply(Engine.call("meter/"+Engine.meter.getString("id"),body));Engine.status="Server နှင့် sync ဖြစ်နေပါတယ်။";}if(!Engine.shouldTrack())handler.post(()->stopSelf());handler.post(()->updateNotification());}catch(Engine.AuthError e){Engine.status=e.getMessage();handler.post(()->stopSelf());}catch(Exception e){Engine.status="Sync မရပါ — "+e.getMessage();}finally{busy=false;}});}handler.postDelayed(this,5000);}};
    @Override public void onCreate(){super.onCreate();Engine.init(this);locations=(LocationManager)getSystemService(LOCATION_SERVICE);NotificationManager manager=getSystemService(NotificationManager.class);manager.createNotificationChannel(new NotificationChannel("meter","Kilo Taxi active trip",NotificationManager.IMPORTANCE_LOW));wake=((PowerManager)getSystemService(POWER_SERVICE)).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"KiloTaxi:Trip");}
    @Override public int onStartCommand(Intent intent,int flags,int startId){if(checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED){Engine.status="Precise GPS permission လိုပါတယ်။";stopSelf();return START_NOT_STICKY;}if(Build.VERSION.SDK_INT>=29)startForeground(41,notification(),ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION);else startForeground(41,notification());if(!Engine.tracking){Engine.tracking=true;try{locations.requestLocationUpdates(LocationManager.GPS_PROVIDER,1000,0,this,Looper.getMainLooper());if(locations.isProviderEnabled(LocationManager.NETWORK_PROVIDER))locations.requestLocationUpdates(LocationManager.NETWORK_PROVIDER,2000,0,this,Looper.getMainLooper());}catch(Exception e){Engine.status="GPS: "+e.getMessage();}handler.post(tick);}return START_NOT_STICKY;}
    private Notification notification(){PendingIntent open=PendingIntent.getActivity(this,0,new Intent(this,MainActivity.class),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);String text=Engine.meter==null?"Trip GPS tracking active":String.format(Locale.US,"%.3f km · %.0f MMK",Engine.meter.optDouble("km"),Engine.meter.optDouble("total"));return new Notification.Builder(this,"meter").setSmallIcon(android.R.drawable.ic_menu_mylocation).setContentTitle("Kilo Taxi · GPS ON").setContentText(text).setOngoing(true).setContentIntent(open).build();}
    private void updateNotification(){if(Engine.tracking)getSystemService(NotificationManager.class).notify(41,notification());}
    @Override public void onLocationChanged(Location location){if(latest==null||location.getTime()>latest.getTime()){latest=location;Engine.accuracy=Math.round(location.getAccuracy())+" m";}}
    @Override public void onProviderDisabled(String provider){Engine.status="Location Services ကို ဖွင့်ပါ။";}
    @Override public void onProviderEnabled(String provider){}
    @Override public void onStatusChanged(String provider,int status,Bundle extras){}
    @Override public void onDestroy(){Engine.tracking=false;handler.removeCallbacks(tick);locations.removeUpdates(this);if(wake!=null&&wake.isHeld())wake.release();stopForeground(STOP_FOREGROUND_REMOVE);super.onDestroy();}
    @Override public IBinder onBind(Intent intent){return null;}
}
