package backend;

class SaveVariables {
    // Mobile-specific variables
    public static var dynamicColors:Bool = true;
    public static var controlsAlpha:Float = 0.8;
    public static var hitboxPos:String = "Bottom"; // Possible values: "Top", "Bottom", etc.
    public static var hitboxType:String = "Normal"; // Possible values: "Normal", "Simple", "Advanced"
    
    // Visual Settings
    public static var dynamicColors:Bool = true;    // Whether the UI uses dynamic colors

    // Add any other save settings you use
    public static var volume:Float = 1.0;
    public static var noteSkin:String = "default";
    public static var downScroll:Bool = false;
    public static var middleScroll:Bool = false;

    // Optional defaults for mods
    public static var modEnabled:Bool = true;
}
