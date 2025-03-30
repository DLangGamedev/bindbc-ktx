module main;

import std.stdio;
import std.conv;

import dagon;

import bindbc.ktx;
import loader = bindbc.loader.sharedlib;

import scene;

// Application class, create your scenes here
class MyGame: Game
{
    MyScene myScene;
    
    this(uint windowWidth, uint windowHeight, bool fullscreen, string title, string[] args)
    {
        super(windowWidth, windowHeight, fullscreen, title, args);
        myScene = New!MyScene(this);
        currentScene = myScene;
    }
}

void main(string[] args)
{
    KTXSupport ktxVersion = loadKTX();
    writeln("KTX version: ", ktxVersion);
    
    if (loader.errors.length)
    {
        writeln("Loader errors:");
        foreach(info; loader.errors)
        {
            writeln(to!string(info.error), ": ", to!string(info.message));
        }
        
        return;
    }
    
    MyGame game = New!MyGame(1280, 720, false, "Dagon template application", args);
    game.run();
    Delete(game);
}
