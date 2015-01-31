package org.ruboto.example.gist2ruboto;

public class Gist2rubotoActivity extends org.ruboto.RubotoActivity {
	public void onCreate(android.os.Bundle arg0) {
    try {
      setSplash(Class.forName("org.ruboto.example.gist2ruboto.R$layout").getField("splash").getInt(null));
    } catch (Exception e) {}

    setScriptName("gist2ruboto_activity.rb");
    super.onCreate(arg0);
  }
}
