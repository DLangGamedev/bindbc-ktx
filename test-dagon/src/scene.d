module scene;

import std.stdio;
import std.path;
import std.algorithm;

import dagon;
import bindbc.ktx;
import vkformat;

bool loadKTX1(InputStream istrm, TextureBuffer* buffer, bool* generateMipmaps)
{
    size_t dataSize = istrm.size;
    ubyte[] data = New!(ubyte[])(dataSize);
    istrm.readBytes(data.ptr, dataSize);
    
    ktxTexture1* tex = null;
    KTX_error_code err = ktxTexture1_CreateFromMemory(data.ptr, dataSize,
        ktxTextureCreateFlagBits.KTX_TEXTURE_CREATE_LOAD_IMAGE_DATA_BIT, &tex);
    if (err != KTX_error_code.KTX_SUCCESS)
    {
        writeln(err);
        return false;
    }
    
    TextureSize size;
    size.width = tex.baseWidth;
    size.height = tex.baseWidth;
    size.depth = tex.baseDepth;
    
    TextureFormat format;
    format.format = tex.glFormat;
    format.internalFormat = tex.glInternalformat;
    format.pixelType = tex.glType;
    
    // Don't use automatic linearlization
    if (format.internalFormat == GL_SRGB8_ALPHA8)
        format.internalFormat = GL_RGBA8;
    else if (format.internalFormat == GL_SRGB8)
        format.internalFormat = GL_RGB8;
    
    if (tex.isCubemap)
    {
        format.target = GL_TEXTURE_CUBE_MAP;
        format.cubeFaces = CubeFaceBit.All;
    }
    else
    {
        if (tex.numDimensions == 1)
            format.target = GL_TEXTURE_1D;
        else if (tex.numDimensions == 2)
            format.target = GL_TEXTURE_2D;
        else if (tex.numDimensions == 3)
            format.target = GL_TEXTURE_3D;
    }
    
    buffer.format = format;
    buffer.size = size;
    buffer.mipLevels = tex.numLevels;
    buffer.data = New!(ubyte[])(tex.dataSize);
    buffer.data[] = tex.pData[0..tex.dataSize];
    
    *generateMipmaps = tex.generateMipmaps;
    
    ktxTexture1_Destroy(tex);
    
    return true;
}

bool loadKTX2(InputStream istrm, TextureBuffer* buffer, bool* generateMipmaps)
{
    size_t dataSize = istrm.size;
    ubyte[] data = New!(ubyte[])(dataSize);
    istrm.readBytes(data.ptr, dataSize);
    
    ktxTexture2* tex = null;
    KTX_error_code err = ktxTexture2_CreateFromMemory(data.ptr, dataSize,
        ktxTextureCreateFlagBits.KTX_TEXTURE_CREATE_LOAD_IMAGE_DATA_BIT, &tex);
    if (err != KTX_error_code.KTX_SUCCESS)
    {
        writeln(err);
        return false;
    }
    
    if (ktxTexture2_NeedsTranscoding(tex))
    {
        // TODO: user-specified format
        // KTX_TTF_RGBA32, KTX_TTF_BC1_RGB, KTX_TTF_BC3_RGBA, KTX_TTF_BC4_R, KTX_TTF_BC5_RG, KTX_TTF_BC7_RGBA, KTX_TTF_ASTC_4x4_RGBA
        ktx_transcode_fmt_e targetFormat = ktx_transcode_fmt_e.KTX_TTF_BC1_RGB;
        err = ktxTexture2_TranscodeBasis(tex, targetFormat, 0);
        if (err != KTX_error_code.KTX_SUCCESS)
        {
            writeln(err);
            return false;
        }
    }
    
    TextureSize size;
    size.width = tex.baseWidth;
    size.height = tex.baseWidth;
    size.depth = tex.baseDepth;
    
    TextureFormat format;
    if (!vkFormatToGL(cast(VkFormat)tex.vkFormat, format))
        return false;
    if (tex.isCubemap)
    {
        format.target = GL_TEXTURE_CUBE_MAP;
        format.cubeFaces = CubeFaceBit.All;
    }
    else
    {
        if (tex.numDimensions == 1)
            format.target = GL_TEXTURE_1D;
        else if (tex.numDimensions == 2)
            format.target = GL_TEXTURE_2D;
        else if (tex.numDimensions == 3)
            format.target = GL_TEXTURE_3D;
    }
    
    buffer.format = format;
    buffer.size = size;
    buffer.mipLevels = tex.numLevels;
    buffer.data = New!(ubyte[])(tex.dataSize);
    
    if (buffer.mipLevels == 1)
    {
        buffer.data[] = tex.pData[0..tex.dataSize];
    }
    else
    {
        // KTX2 stores mip levels in reverse order
        uint w = 1;
        uint h = 1;
        size_t srcOffset = 0;
        const uint blockWidth = 4;
        const uint blockHeight = 4;
        const uint pixelSize = format.pixelSize;
        for (uint m = 0; m < buffer.mipLevels; m++)
        {
            size_t mipSize;
            if (format.isCompressed)
                mipSize = ((w + blockWidth - 1) / blockWidth) * ((h + blockHeight - 1) / blockHeight) * format.blockSize;
            else
                mipSize = w * h * pixelSize;
            
            for(size_t i = 0; i < mipSize; i++)
            {
                buffer.data[tex.dataSize - srcOffset - mipSize + i] = tex.pData[srcOffset + i];
            }
            
            srcOffset += mipSize;
            w *= 2;
            h *= 2;
        }
    }
    
    *generateMipmaps = tex.generateMipmaps;
    
    ktxTexture2_Destroy(tex);
    
    return true;
}

class KTXAsset: Asset
{
    Texture texture;
    protected TextureBuffer buffer;
    protected bool generateMipmaps = true;
    
    this(Owner o)
    {
        super(o);
        texture = New!Texture(this);
    }
    
    ~this()
    {
        release();
    }
    
    override bool loadThreadSafePart(string filename, InputStream istrm, ReadOnlyFileSystem fs, AssetManager assetManager)
    {
        string ext = filename.extension;
        if (ext == ".ktx" || ext == ".KTX")
            return loadKTX1(istrm, &buffer, &generateMipmaps);
        else if (ext == ".ktx2" || ext == ".KTX2")
            return loadKTX2(istrm, &buffer, &generateMipmaps);
        else
            return false;
    }
    
    override bool loadThreadUnsafePart()
    {
        if (texture.valid)
            return true;
        
        if (buffer.data.length)
        {
            texture.createFromBuffer(buffer, generateMipmaps);
            Delete(buffer.data);
            return true;
        }
        else
            return false;
    }
    
    override void release()
    {
        if (texture)
            texture.release();
        if (buffer.data.length)
            Delete(buffer.data);
    }
}

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
