package;

import lumod.Lumod;
#if AWAY_TEST
import states.stages.AwayStage;
#end
import states.MainMenuState;
import externs.WinAPI;
import haxe.Exception;
import flixel.graphics.FlxGraphic;
import haxe.io.Path;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import states.TitleState;
#if COPYSTATE_ALLOWED
import states.CopyState;
#end
#if mobile
import mobile.backend.MobileScaleMode;
#end

#if linux
import lime.graphics.Image;
#end

import sys.FileSystem;

class Main extends Sprite
{
	var game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: TitleState, // initial game state
		zoom: -1.0, // game state bounds
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var fpsVar:FPS;

	public static final platform:String = #if mobile "Phones" #else "PCs" #end;
	#if AWAY_TEST
	public static var stage3D:AwayStage;
	#end

	public static final PSYCH_ONLINE_VERSION:String = "0.10.1";
	public static final CLIENT_PROTOCOL:Float = 7;
	public static final GIT_COMMIT:String = online.backend.Macros.getGitCommitHash();

	public static var wankyUpdate:String = 'version';

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		#if !mobile // would crash the game
		if (Path.normalize(Sys.getCwd()) != Path.normalize(lime.system.System.applicationDirectory)) {
			Lib.application.window.alert("Your path is either not run from the game directory,\nor contains illegal UTF-8 characters!\n\nRun from: "
				+ Sys.getCwd()
				+ "\nExpected path: " + lime.system.System.applicationDirectory, 
			"Invalid Runtime Path!");
			Sys.exit(1);
		}
		#end

		sys.ssl.Socket.DEFAULT_VERIFY_CERT = false;
		Lib.current.addChild(new Main());
		//TBA
		Lib.current.addChild(new online.gui.sidebar.SideUI());
	}

	public function new()
	{
		super();
		#if mobile
		#if android
		StorageUtil.requestPermissions();
		#end
		Sys.setCwd(StorageUtil.getStorageDirectory());
		#end
		backend.CrashHandler.init();

		#if windows
		@:functionCode("
			#include <windows.h>
			#include <winuser.h>
			setProcessDPIAware() // allows for more crisp visuals
			DisableProcessWindowsGhosting() // lets you move the window and such if it's not responding
		")
		#end

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		#if (openfl <= "9.2.0")
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (game.zoom == -1.0)
		{
			var ratioX:Float = stageWidth / game.width;
			var ratioY:Float = stageHeight / game.height;
			game.zoom = Math.min(ratioX, ratioY);
			game.width = Math.ceil(stageWidth / game.zoom);
			game.height = Math.ceil(stageHeight / game.zoom);
		}
		#else
		if (game.zoom == -1.0)
			game.zoom = 1.0;
		#end

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		CoolUtil.setDarkMode(true);

		Lumod.scriptPathHandler = scriptPath -> {
			var defaultPath:String = 'lumod/' + scriptPath;

			// check if script exists in any of loaded mods
			var path:String = Paths.modFolders(defaultPath);
			if (FileSystem.exists(path))
				return path;

			return defaultPath;
		}
		Lumod.classResolver = Deflection.resolveClass;

		#if hl
		sys.ssl.Socket.DEFAULT_VERIFY_CERT = false;
		#end

		#if AWAY_TEST
		addChild(stage3D = new AwayStage());
		#end
	
		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		addChild(new FlxGame(game.width, game.height, #if COPYSTATE_ALLOWED !CopyState.checkExistingFiles() ? CopyState : #end game.initialState, #if (flixel < "5.0.0") game.zoom, #end game.framerate, game.framerate, game.skipSplash, game.startFullscreen));

		fpsVar = new FPS(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.data.showFPS;
		}

		#if linux
		Lib.current.stage.window.setIcon(Image.fromFile("icon.png"));
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = #if mobile 30 #else 60 #end;
		#if web
		FlxG.keys.preventDefaultKeys.push(TAB);
		#else
		FlxG.keys.preventDefaultKeys = [TAB];
		#end

		#if android FlxG.android.preventDefaultKeys = [BACK]; #end

		#if DISCORD_ALLOWED
		DiscordClient.start();
		#end

		#if mobile
		lime.system.System.allowScreenTimeout = ClientPrefs.data.screensaver; 		
		FlxG.scaleMode = new MobileScaleMode();
		#end

		// shader coords fix
		FlxG.signals.gameResized.add(function (w, h) {
			if(fpsVar != null)
				fpsVar.positionFPS(10, 3, Math.min(w / FlxG.width, h / FlxG.height));

		     if (FlxG.cameras != null) {
			   for (cam in FlxG.cameras.list) {
				@:privateAccess
				if (cam != null && cam._filters != null)
					resetSpriteCache(cam.flashSprite);
			   }
		     }

		     if (FlxG.game != null)
			 resetSpriteCache(FlxG.game);
		});

		//ONLINE STUFF, BELOW CODE USE FOR BACKPORTING

		var http = new haxe.Http("https://raw.githubusercontent.com/MobilePorting/Funkin-Psych-Online-Mobile/main/server_addresses.txt");
		http.onData = function(data:String) {
			for (address in data.split(',')) {
				online.GameClient.serverAddresses.push(address.trim());
			}
		}
		http.onError = function(error) {
			trace('error: $error');
		}
		http.request();
		#if LOCAL
		online.GameClient.serverAddresses.insert(0, "ws://localhost:2567");
		#else
		online.GameClient.serverAddresses.push("ws://localhost:2567");
		#end
		online.network.FunkinNetwork.client = new online.util.HTTPClient(online.GameClient.addressToUrl());

		online.mods.Downloader.checkDeleteDlDir();

		addChild(new online.gui.LoadingScreen());
		addChild(new online.gui.Alert());
		addChild(new online.gui.DownloadAlert.DownloadAlerts());

		FlxG.plugins.add(new online.backend.Waiter());

		online.backend.Thread.repeat(() -> {
			try {
				online.network.FunkinNetwork.ping();
			}
			catch (exc) {
				trace(exc);
			}
		}, 60, _ -> {}); // ping the server every minute
		
		//for some reason only cancels 2 downloads
		Lib.application.window.onClose.add(() -> {
			#if DISCORD_ALLOWED
			DiscordClient.shutdown();
			#end
			online.mods.Downloader.cancelAll();
			online.mods.Downloader.checkDeleteDlDir();
			online.network.Auth.saveClose();
		});

		#if !mobile
		Lib.application.window.onDropFile.add(path -> {
			if (FileSystem.isDirectory(path))
				return;

			if (path.endsWith(".json") && (path.contains("-chart") || path.contains("-metadata"))) {
				online.util.vslice.VUtil.convertVSlice(path);
			}
			else {
				online.backend.Thread.run(() -> {
					online.gui.LoadingScreen.toggle(true);
					online.mods.OnlineMods.installMod(path);
					online.gui.LoadingScreen.toggle(false);
				});
			}
		});
		#end
		
		#if HSCRIPT_ALLOWED
		FlxG.signals.postStateSwitch.add(() -> {
			online.backend.SyncScript.dispatch("switchState", [FlxG.state]);

			FlxG.state.subStateOpened.add(substate -> {
				online.backend.SyncScript.dispatch("openSubState", [substate]);
			});
		});

		FlxG.signals.postUpdate.add(() -> {
			if (online.backend.SyncScript.activeUpdate)
				online.backend.SyncScript.dispatch("update", [FlxG.elapsed]);
		});

		online.backend.SyncScript.resyncScript(false, () -> {
			online.backend.SyncScript.dispatch("init");
		});
		#end
	}

	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
		        sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}
}
