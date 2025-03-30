module scene;

import dagon;
import ktx;

class MyScene: Scene
{
    Game game;
    
    KTXAsset aTexture1;
    KTXAsset aTexture2;

    this(Game game)
    {
        super(game);
        this.game = game;
    }

    override void beforeLoad()
    {
        aTexture1 = New!KTXAsset(assetManager);
        addAsset(aTexture1, "data/test.ktx");
        
        aTexture2 = New!KTXAsset(assetManager);
        addAsset(aTexture2, "data/test.ktx2");
    }
    
    override void onLoad(Time t, float progress)
    {
        // Do something each frame while assets are loading
    }

    override void afterLoad()
    {
        // Create entities, materials, initialize game logic
        auto camera = addCamera();
        auto freeview = New!FreeviewComponent(eventManager, camera);
        freeview.setZoom(5);
        freeview.setRotation(30.0f, -45.0f, 0.0f);
        freeview.translationStiffness = 0.25f;
        freeview.rotationStiffness = 0.25f;
        freeview.zoomStiffness = 0.25f;
        game.renderer.activeCamera = camera;

        auto sun = addLight(LightType.Sun);
        sun.shadowEnabled = true;
        sun.energy = 10.0f;
        sun.pitch(-45.0f);
        
        auto matCube1 = addMaterial();
        matCube1.baseColorTexture = aTexture1.texture;

        auto eCube1 = addEntity();
        eCube1.drawable = New!ShapeBox(Vector3f(1, 1, 1), assetManager);
        eCube1.material = matCube1;
        eCube1.position = Vector3f(-1.5, 1, 0);
        eCube1.turn(45);
        
        auto matCube2 = addMaterial();
        matCube2.baseColorTexture = aTexture2.texture;

        auto eCube2 = addEntity();
        eCube2.drawable = New!ShapeBox(Vector3f(1, 1, 1), assetManager);
        eCube2.material = matCube2;
        eCube2.position = Vector3f(1.5, 1, 0);
        
        auto ePlane = addEntity();
        ePlane.drawable = New!ShapePlane(10, 10, 1, assetManager);
        
        game.deferredRenderer.ssaoEnabled = true;
        game.deferredRenderer.ssaoPower = 6.0;
        game.postProcessingRenderer.fxaaEnabled = true;
    }
    
    // Event callbacks:
    override void onUpdate(Time t) { }
    override void onKeyDown(int key) { }
    override void onKeyUp(int key) { }
    override void onTextInput(dchar code) { }
    override void onMouseButtonDown(int button) { }
    override void onMouseButtonUp(int button) { }
    override void onMouseWheel(int x, int y) { }
    override void onJoystickButtonDown(int btn) { }
    override void onJoystickButtonUp(int btn) { }
    override void onJoystickAxisMotion(int axis, float value) { }
    override void onResize(int width, int height) { }
    override void onFocusLoss() { }
    override void onFocusGain() { }
    override void onDropFile(string filename) { }
    override void onUserEvent(int code) { }
    override void onQuit() { }
}
