'use strict';
const Amaz = effect.Amaz;

const SCRIPT_NAME = 'koreansweetgirl';

/**
 * @field {String} Channel - {
*    "display": "combobox",
*    "label": "component_gan_channel",
*    "default": "Texture",
*    "options": [
*        {"label": "component_gan_channel_texture",   "value": "Texture"},
*        {"label": "component_gan_channel_distortion",   "value": "Distortion"}
*     ]
* }
* @field {Number} Intensity - {
*    "display": "slider",
*    "label": "component_gan_intensity",
*    "default": 1.0,
*	  "step": 0.1,
*	  "precision": 2,
*    "range": { "min": 0, "max": 1.0 },
*     "showIf": "Channel",
*     "showIfValue": "Distortion"
* }
 */
class koreansweetgirl {
  constructor() {
    this.name = "koreansweetgirl";
    this.ganTextureUniform = "ganTexture";
    this.flowTextureUniform = "flowTexture";
    this.ganTransform = "mvpMat"
    this.enableUniform = "enable";
    this.isGanUniform = "isGan";
    this.flowLevelUniform = "flowLevel";
    this.ganCamera = null;

    this.materialPath = "koreansweetgirl/gan.material";
    this.material = null;
    this.cb = new Amaz.CommandBuffer();
    this.graphName = "";
    this.MeshRender = undefined;
    this.ganEnabled = false;

    this.preChannel = "";
  }

  onStart()
    {
        this.material = this.scene.assetMgr.SyncLoad(this.materialPath).instantiate();

        const parentTrans = this.entity.getComponent("Transform").parent;
        for(var i = 0; i < parentTrans.children.size(); i++){
            const child = parentTrans.children.get(i);
            if(child.entity.getComponent("Camera")){
                this.ganCamera = child.entity.getComponent("Camera");
                this.script.addScriptListener(this.ganCamera, Amaz.CameraEvent.RENDER_IMAGE_EFFECTS, "renderGANEffects", this.script);
                var colorFormat = Amaz.PixelFormat.RGBA8Unorm;
                if (this.ganCamera.renderTexture.realColorFormat == Amaz.PixelFormat.RGBA16Sfloat || this.ganCamera.renderTexture.realColorFormat == Amaz.PixelFormat.RGBA32Sfloat)
                {
                    colorFormat = this.ganCamera.renderTexture.colorFormat;
                }
                this.dstCopy = this.createRenderTexture("dstCopy", this.ganCamera.renderTexture.width, this.ganCamera.renderTexture.height, colorFormat);
                // this.cb.clearAll();
                // this.cb.blit(this.ganCamera.renderTexture, this.dstCopy);
                // this.cb.blitWithMaterial(this.dstCopy, this.ganCamera.renderTexture, this.material, 0);
                break;
            }
        }

        this.faceIndices = new Amaz.Vector(); 
        this.faceIndices.pushBack(0);

        let tex = new Amaz.Texture2D();
        this.material.setTex(this.ganTextureUniform, tex); // the tex currently is empty, create a tex, for future use in shader
        this.material.setFloat(this.enableUniform, 0);

        
    }

  show()
    {
        let Algorithm = Amaz.AmazingManager.getSingleton('Algorithm');
        let result = Algorithm.getAEAlgorithmResult(this.graphName);
        let ganInfo = result.getAlgorithmInfo(this.graphName, "script_0", "", 0);
        let flowInfo = result.getAlgorithmInfo(this.graphName, "script_0", "", 1);
        let tfmInfo = result.getNHImageTfmInfo(this.graphName, "FaceAlign", 0);
        let transform=this.entity.getComponent("Transform");
        if(transform===undefined){
            console.error("transform is undefined")
             
        }
        else{
            transform.worldOrientation=new Amaz.Vector3f(0,0,0);
            transform.worldPosition=new Amaz.Vector3f(0,0,0);
            transform.worldScale=new Amaz.Vector3f(1,1,1);
        }
 

        if (ganInfo && tfmInfo && flowInfo)
        {
            this.ganEnabled = true;

            this.material.setMat4(this.ganTransform, tfmInfo.mvp);
            this.material.setTex(this.ganTextureUniform, ganInfo.texture)
            this.material.setTex(this.flowTextureUniform, flowInfo.texture)
            this.material.setFloat(this.enableUniform,1);

            this.material.setFloat(this.isGanUniform, this.Channel==="Distortion"?0:1);
            this.material.setFloat(this.flowLevelUniform, this.Intensity);
        }

        else
        {
            this.ganEnabled = false;
            this.material.setFloat(this.enableUniform,0);
        }
        
    }

  onUpdate(deltaTime)
  {

    if(this.preChannel !== this.Channel && this.ganCamera && this.dstCopy){
        this.cb.clearAll();
        this.cb.blit(this.ganCamera.renderTexture, this.dstCopy);
        this.cb.blitWithMaterial(this.dstCopy, this.ganCamera.renderTexture, this.material, 0);
        this.preChannel = this.Channel;
    }
      
      this.show();
      
  }

  onDestroy(sys)
    {
        if (this.ganCamera !== null)
        {
            this.script.removeScriptListener(this.ganCamera, Amaz.CameraEvent.RENDER_IMAGE_EFFECTS, "renderGANEffects", this.script);
        }
    }

    renderGANEffects(sys, camera, eventType) {
        if (camera.entity.visible && camera.enabled && this.entity.visible && this.ganEnabled && eventType == Amaz.CameraEvent.RENDER_IMAGE_EFFECTS)
        {
            // Amaz.LOGE("hello", "draw");
            camera.entity.scene.commitCommandBuffer(this.cb);
        }
    }

    createRenderTexture(name, width, height, colorFormat) {
        var rt = new Amaz.RenderTexture();
        rt.name = name;
        rt.builtinType = Amaz.BuiltInTextureType.NORMAL;
        rt.internalFormat = Amaz.InternalFormat.RGBA8;
        rt.dataType = Amaz.DataType.U8norm;
        rt.depth = 1
        rt.attachment = Amaz.RenderTextureAttachment.DEPTH24;
        rt.filterMag = Amaz.FilterMode.LINEAR;
        rt.filterMin = Amaz.FilterMode.LINEAR;
        rt.filterMipmap = Amaz.FilterMipmapMode.FilterMode_NONE;
        rt.width = width;
        rt.height = height;
        rt.colorFormat = colorFormat || Amaz.PixelFormat.RGBA8Unorm;
        return rt;
    }

    onEnable()
    {
        this.ganEnabled = true;
        this.dynamicSetAlgorithmEnable(true);
    }

    onDisable()
    {
        this.ganEnabled = false;
        this.dynamicSetAlgorithmEnable(false);

    }

    dynamicSetAlgorithmEnable(enable) {
        let Algorithm = Amaz.AmazingManager.getSingleton('Algorithm');
        const algoList = ["blit_0", "face_0", "expression_detect_0","FaceAlign","script_0"];
        if (enable) {
          for (let i = 0; i < algoList.length; ++i) {
            Algorithm.setAlgorithmEnable(this.graphName, algoList[i], true);
          }
        } else {
          for (let i = algoList.length - 1; i >= 0; --i) {
            Algorithm.setAlgorithmEnable(this.graphName, algoList[i], false);
          }
        }
      }

}


exports.koreansweetgirl = koreansweetgirl;