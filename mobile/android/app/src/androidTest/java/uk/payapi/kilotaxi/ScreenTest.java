package uk.payapi.kilotaxi;

import android.graphics.Bitmap;
import android.widget.EditText;
import android.widget.TextView;
import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public class ScreenTest {
    private Object field(MainActivity a,String name) throws Exception {var f=MainActivity.class.getDeclaredField(name);f.setAccessible(true);return f.get(a);}
    private void capture(String name) throws Exception {var i=InstrumentationRegistry.getInstrumentation();i.waitForIdleSync();Bitmap image=i.getUiAutomation().takeScreenshot();assertNotNull(image);File out=new File(i.getTargetContext().getExternalFilesDir(null),name+".png");try(var stream=new FileOutputStream(out)){assertTrue(image.compress(Bitmap.CompressFormat.PNG,100,stream));}image.recycle();}
    @Test public void loginAndMeterScreens() throws Exception {
        var i=InstrumentationRegistry.getInstrumentation();
        i.getTargetContext().getSharedPreferences("session",0).edit().clear().commit();
        try(var scenario=ActivityScenario.launch(MainActivity.class)){
            i.waitForIdleSync();
            scenario.onActivity(a->{try{EditText username=(EditText)field(a,"username");assertTrue(username.isShown());assertTrue(username.getWidth()>0);assertTrue(((EditText)field(a,"password")).isShown());}catch(Exception e){throw new AssertionError(e);}});
            capture("01-login");
            scenario.onActivity(a->{try{
                Engine.prefs.edit().putString("origin","https://example.invalid").putString("cookie","taxi_session=screenshot-test").commit();
                Engine.user=new JSONObject("{\"name\":\"အောင်ခန့်ပိုင်\",\"vehicleNumber\":\"YGN 7A-1234\",\"permissions\":[\"calculate\",\"save_trips\",\"view_own\"]}");
                Engine.meter=new JSONObject("{\"id\":\"demo\",\"state\":\"waiting\",\"km\":12.475,\"total\":18700,\"waitingEnabled\":true,\"waitingSeconds\":342}");
                Engine.tracking=false;Engine.status="မီတာ sync ဖြစ်နေပါတယ်။";Engine.accuracy="8 m";
                var method=MainActivity.class.getDeclaredMethod("showMeter");method.setAccessible(true);method.invoke(a);
                assertEquals("12.475",((TextView)field(a,"kmValue")).getText().toString());assertEquals("342",((TextView)field(a,"secondsValue")).getText().toString());
                assertFalse(((TextView)field(a,"logout")).isEnabled());
            }catch(Exception e){throw new AssertionError(e);}});
            capture("02-meter");
        } finally {Engine.prefs.edit().clear().commit();Engine.meter=null;Engine.user=null;Engine.tracking=false;}
    }
}
