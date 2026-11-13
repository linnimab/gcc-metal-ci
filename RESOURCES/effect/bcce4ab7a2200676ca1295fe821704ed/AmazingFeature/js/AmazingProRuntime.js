/**
 * Note: This file intentionally excludes certain modules during dependency export
 * (e.g., `NetworkManager`, `AudioDetection`), including the APJS `Map` files.
 * If you add new dependencies on APJS `Map` later, you must manually update the
 * `extraExcludeDependenciesInfo` list in APJSDependyManager.ts in OrionSDK.
 */
const apjs = require('amazingpro.js');
let PropertyBridge;
try {
  PropertyBridge = require('PropertyBridge').PropertyBridge;
} catch (e) {
  void e;
}
let iejs;
try {
  iejs = require('IEJS.js');
} catch (e) {
  void e;
}

globalThis.isInternalIndex = 1;

const Amaz = effect.Amaz;
const TimeLineComponentType = 'TimelinePlayer';
const OnLateUpdateCallback = 'onLateUpdate';
const DynamicComponentType = 'DynamicComponent';
const JSScriptComponentType = 'JSScriptComponent';

const multiLayerPropertySeparator = '%';

function isMultiLayerProperty(encodedPropertyName)
{
  return encodedPropertyName.startsWith(multiLayerPropertySeparator);
}

function decodeMultiLayerProperty(encodedPropertyName)
{
  if (!isMultiLayerProperty(encodedPropertyName)) {
    return encodedPropertyName;
  }
  return encodedPropertyName.substring(multiLayerPropertySeparator.length);
}

class AmazingProRuntime {
  constructor() {
    this.name = 'AmazingProRuntime';
    this.amazingProInstances = new Array();
    this.allDynamicComponents = [];
    this.mixDynamicComponents = [];
    this.systemInited = false;
    this.systemStarted = false;
    this.isMixEnable = false;
    this.guidToObjMap = new Map();
    this.skipOnLateUpdate = false;
    this.cacheAddedComponents = new Set(); // Set<effect.Amaz.Component>
    this.subsystems = new Array();
    this.subsystemNameToDataMap = new Map(); // Map<system name, {instance, components}>
    this.hasNetworkManager = true;
  }

  onInit() {
    try {
      apjs.NetworkManager && apjs.NetworkManager.initialize(this.script);
    } catch (e) {
      this.hasNetworkManager = false;
    }

    this.checkAndCreateSubSystem(); //FIXME: remove this line after 3D Physics Components all moved to APJS;
    this.jsAssetManager = new apjs.DynamicAssetRuntimeManager();
    apjs.setDynamicAssetRuntimeManager(this.jsAssetManager);
    // EventManager Init
    apjs.EventManager.initialize(this.script);

    Object.defineProperty(apjs, 'scene', {
      writable: false,
      configurable: false,
      enumerable: false,
      value: this.scene,
    });
    this.script.handleComponentName('DynamicComponent');
    this.jsAssetManager.setCurrentScene(apjs.transferToAPJSObj(this.scene));
    this.jsAssetManager.checkAndLoadJSAsset();
    for (const system of this.subsystems) {
      if(system.hasOwnProperty('jsScript')){
        system.jsScript = this.script;
      }
      system.onInit();
    }

    // IEJs register some variables
    if (iejs && iejs.Util && iejs.Util.Const) {
      iejs.Util.Const.registerVars({scene: new apjs.Scene(this.scene)});
    }
    this.systemInited = true;
  }

  onStart() {
    this.updateAudioDetectorBuilderAvailable();
    apjs.setDynamicAssetRuntimeManager(this.jsAssetManager);
    for (const system of this.subsystems) {
      system.onStart();
    }
    for (let i = 0; i < this.allDynamicComponents.length; i++) {
      const customComp = this.allDynamicComponents[i];
      if (customComp.isInheritedEnabled() && !customComp.started) {
        customComp.started = true;
        this.dynamicComponentOnCall(customComp, 'onStart');
      }
    }

    this.jsAssetManager.onStart();
    this.systemStarted = true;
    this.jsAssetManager.setSystemStarted(true);
    this.checkAndInitMixEnableFlag();
  }

  onGameEvent(event) {
    const apjsEvent = apjs.transferToAPJSObj(event);

    for (let i = 0; i < this.allDynamicComponents.length; i++) {
      const customComp = this.allDynamicComponents[i];
      if (customComp && customComp.constructor.name === 'GameComponent') {
        this.dynamicComponentOnCall(customComp, 'onGameEvent', apjsEvent);
      }
    }
  }

  onMixUpdate(dt)
  {
    const dynamicComponents = this.getDynamicComponents();
    for (let i = 0; i < dynamicComponents.length; i++) {
      const customComp = dynamicComponents[i];
      if (customComp && customComp.isInheritedEnabled()) {
        this.dynamicComponentOnCall(customComp, 'onUpdate', dt);
      }
    }
  }

  onMixLateUpdate(dt)
  {
    const dynamicComponents = this.getDynamicComponents();
    for (let i = 0; i < dynamicComponents.length; i++) {
      const customComp = dynamicComponents[i];
      if (customComp && customComp.isInheritedEnabled()) {
        this.dynamicComponentOnCall(customComp, 'onLateUpdate', dt);
      }
    }
  }

  onUpdate(dt) {
    apjs.checkAndClearHandleCache();
    apjs.AlgorithmManager.clearResult();
    apjs.setDynamicAssetRuntimeManager(this.jsAssetManager);
    apjs.MathNativeObjectPool.update();
    if (this.hasNetworkManager) {
      apjs.NetworkManager.onUpdate();
    }

    for (const system of this.subsystems) {
      system.onUpdate(dt);
    }
    if (!this.isMixEnable)
    {
      const dynamicComponents = this.getDynamicComponents();
      for (let i = 0; i < dynamicComponents.length; i++)
      {
        const customComp = dynamicComponents[i];
        if (customComp && customComp.isInheritedEnabled())
        {
          this.dynamicComponentOnCall(customComp, 'onUpdate', dt);
        }
      }
    }

    this.jsAssetManager.onUpdate(dt);
    // SceneEvent
    apjs.EventManager.onUpdate(dt);

    if (this.script.registerIgnoreLifeCycleCallback) {
      if (
        !this.skipOnLateUpdate &&
        !this.jsAssetManager.hasOnLateUpdateAsset() &&
        !this.hasOnLateUpdateDynamicComponent() &&
        !this.hasRegisteredOnLateUpdateEvent()
      ) {
        // If no assets and components have onLateUpdate, we skip the onLateUpdate call
        this.script.registerIgnoreLifeCycleCallback(OnLateUpdateCallback);
        this.skipOnLateUpdate = true;
      } else if (
        this.skipOnLateUpdate &&
        (this.jsAssetManager.hasOnLateUpdateAsset() ||
          this.hasOnLateUpdateDynamicComponent() ||
          this.hasRegisteredOnLateUpdateEvent())
      ) {
        this.script.unregisterIgnoreLifeCycleCallback(OnLateUpdateCallback);
        this.skipOnLateUpdate = false;
      }
    }
  }
  onLateUpdate(dt) {
    apjs.setDynamicAssetRuntimeManager(this.jsAssetManager);
    for (const system of this.subsystems) {
      system.onLateUpdate(dt);
    }
    if (!this.isMixEnable)
    {
      for (let i = 0; i < this.allDynamicComponents.length; i++) {
        const customComp = this.allDynamicComponents[i];
        if (customComp && customComp.isInheritedEnabled()) {
          this.dynamicComponentOnCall(customComp, 'onLateUpdate', dt);
        }
      }
    }

    this.jsAssetManager.onLateUpdate(dt);
    // SceneEvent
    apjs.EventManager.onLateUpdate(dt);
  }
  onComponentAdded(comp) {
    if (
      comp &&
      (comp.constructor.name === DynamicComponentType ||
        comp.constructor.__nativeClassName === DynamicComponentType)
    ) {
      const sceneObject = apjs.transferToAPJSObj(comp.entity);
      if (sceneObject) {
        const apjsClassName = comp.className;
        if (apjsClassName === TimeLineComponentType) {
          if (!this.propertyBridge && PropertyBridge) {
            this.propertyBridge = new PropertyBridge();
            this.propertyBridge.init(this.scene);
          }
        }
        const apjsComponent = sceneObject.getDynamicComponentByRtti(comp);
        this.initDynamicComponentProperty(apjsComponent);
        if (apjsComponent) {
          this.ensureSubsystem(apjsComponent);
          this.cacheAddedComponents.add(apjsComponent.getNative());
          this.allDynamicComponents.push(apjsComponent);
          this.dynamicComponentOnCall(apjsComponent, 'onInit');
          if (apjsComponent.isInheritedEnabled()) {
          this.dynamicComponentOnCall(apjsComponent, 'onEnable');
          if (this.systemStarted) {
            apjsComponent.started = true;
            apjsComponent.onStart();
          }
        }
          for (const subsystem of this.subsystems.values()) {
            subsystem.onComponentAdded(apjsComponent.getNative());
          }
          // SceneEvent
          apjs.EventManager.onComponentAdded(apjsComponent);
        }
      }
    } else if (comp && comp.constructor.name === 'JSScriptComponent') {
      // FIXME: remove after 3D Physics Components all moved to APJS
      for (const subsystem of this.subsystems.values()) {
        subsystem.onComponentAdded(comp);
      }
    }
  }

  onComponentRemoved(comp) {
    if (
      comp &&
      (comp.constructor.name === DynamicComponentType ||
        comp.constructor.__nativeClassName === DynamicComponentType)
    ) {
      const sceneObject = apjs.transferToAPJSObj(comp.entity);
      if (sceneObject) {
        const apjsComponent = sceneObject.getDynamicComponentByRtti(comp);
        if (apjsComponent) {
          const index = this.allDynamicComponents.indexOf(apjsComponent);
          if (index > -1) {
            this.allDynamicComponents.splice(index, 1);
          }
          if (apjsComponent.isInheritedEnabled()) {
            this.dynamicComponentOnCall(apjsComponent, 'onDisable');
          }
          for (const subsystem of this.subsystems.values()) {
            subsystem.onComponentRemoved(comp);
          }
          this.removeSubsystemIfUnused(apjsComponent);
          // SceneEvent
          apjs.EventManager.onComponentRemoved(apjsComponent);
          this.dynamicComponentOnCall(apjsComponent, 'onDestroy');
          comp.ref = null;
          comp.refReleased = true;
        }
      }
    } else if (comp && comp.constructor.name === 'JSScriptComponent') {
      // FIXME: remove after 3D Physics Components all moved to APJS
      for (const subsystem of this.subsystems.values()) {
        subsystem.onComponentRemoved(comp);
      }
    }
  }

  onMixAttachedDynamicComponent(dynamicComponents)
  {
    for (let i = 0; i < dynamicComponents.size(); ++i)
    {
      const comp = dynamicComponents.get(i);
      if (
        comp &&
        (comp.constructor.name === DynamicComponentType ||
          comp.constructor.__nativeClassName === DynamicComponentType)
      ) {
        const sceneObject = apjs.transferToAPJSObj(comp.entity);

        if (sceneObject) {
          //this apjsComponent has been onInit/onStart in onComponentAdded, so do not need call these methods again.
          const apjsComponent = sceneObject.getDynamicComponentByRtti(comp);
          this.initDynamicComponentProperty(apjsComponent);
          this.mixDynamicComponents.push(apjsComponent);
        }
      }
    }
  }

  initDynamicComponentProperty(apjsComponent)
  {
    if (apjsComponent) {
      // init apjsComponent properties
      const serializedProperty = apjsComponent.getNative().serializedProperty;
      if (serializedProperty) {
        const props = serializedProperty.properties;
        if (props) {
          const keys = props.getVectorKeys();
          const size = keys.size();
          for (let i = 0; i < size; i++) {
            const key = keys.get(i);
            const value = props.get(key);
            if (
              apjs.isJSArraySerializedProperty(apjsComponent.constructor, key) &&
              value instanceof effect.Amaz.Vector
            ) {
              const jsArray = new Array(value.size());
              for (let i = 0; i < jsArray.length; i++) {
                const item = value.get(i);
                if (
                  item instanceof effect.Amaz.Transform &&
                  apjs.isSceneObjectSerializedProperty(apjsComponent.constructor, key)
                ) {
                  jsArray[i] = apjs.transferToAPJSObj(item.entity);
                } else {
                  jsArray[i] = apjs.transferToAPJSObj(item);
                }
              }
              apjsComponent[key] = jsArray;
            } else {
              apjsComponent[key] = apjs.transferToAPJSObj(value);
            }
          }
        }
      }
    }
  }

  onMixAllComponentsDetached()
  {
    this.mixDynamicComponents = [];
  }

  getDynamicComponents()
  {
    if (this.isMixEnable)
    {
      return this.mixDynamicComponents;
    }
    return this.allDynamicComponents;
  }

  hasOnLateUpdateDynamicComponent() {
    let hasOnLateUpdate = false;
    const dynamicComponents = this.getDynamicComponents();
    for (let i = 0; i < dynamicComponents.length; i++) {
      const customComp = dynamicComponents[i];
      // if child class overrides DynamicComponent onLateUpdate
      if (Object.getPrototypeOf(customComp).onLateUpdate !== apjs.DynamicComponent.prototype.onLateUpdate) {
        hasOnLateUpdate = true;
      }
    }
    for (const system of this.subsystems.values())
    {
      if (typeof system.onLateUpdate === 'function')
      {
        hasOnLateUpdate = true;
      }
    }
    return hasOnLateUpdate;
  }

  hasRegisteredOnLateUpdateEvent() {
    if (
      apjs.EventManager.EventManager__globalEmitter &&
      apjs.EventManager.EventManager__globalEmitter.has(OnLateUpdateCallback)
    ) {
      return true;
    }
    return false;
  }

  onEvent(event) {
    const apjsEvent = apjs.transferToAPJSObj(event);
    for (const system of this.subsystems.values()) {
      system.onEvent(event);
    }
    apjs.setDynamicAssetRuntimeManager(this.jsAssetManager);
    //=========================================================================
    //TODO: need delete
    for (let i = 0; i < this.allDynamicComponents.length; i++) {
      const customComp = this.allDynamicComponents[i];
      if (customComp) {
        this.dynamicComponentOnCall(customComp, 'onEvent', apjsEvent);
      }
    }
    //=========================================================================
    this.jsAssetManager.onEvent(apjsEvent);
    apjs.EventManager.onGlobalEvent(apjsEvent);
  }

  onDestroy() {
    this.onMixAllComponentsDetached();
    apjs.setDynamicAssetRuntimeManager(this.jsAssetManager);
    if (this.hasNetworkManager) {
      apjs.NetworkManager.finalize();
    }

    for (const customComp of this.allDynamicComponents) {
      customComp && this.dynamicComponentOnCall(customComp, 'onDestroy');
    }
    for (const system of this.subsystems) {
      system.onDestroy();
    }

    this.guidToObjMap.clear();
    this.jsAssetManager.onDestroy();
    // finalize
    apjs.EventManager.finalize();

    //  // IEJs unregister
    if (iejs && iejs.Util && iejs.Util.Const) {
      iejs.Util.Const.unregisterVars();
    }
    apjs.clearObjectCache();

    for (const customComp of this.allDynamicComponents) {
      customComp && (customComp.getNative().ref = null);
      customComp && (customComp.getNative().refReleased = true);
    }
  }

  onSerializedPropertyChanged(guid, serializedProperty) {}

  onDualInstanceScriptMethodCall(guid, methodName, value, value2) {
    let obj = this.guidToObjMap.get(guid.toString());
    if (!obj) {
      obj = apjs.AmazingManager.guidToPointer(new apjs.Guid(guid));
      this.guidToObjMap.set(guid.toString(), obj);
    }
    // serialized array property
    const isSerializedArrayPropery = apjs.isJSArraySerializedProperty(
      obj.constructor,
      methodName
    );
    const isDualInstanceArrayProperty = apjs.isJSArrayDualInstanceProperty(
      obj.constructor,
      methodName
    );
    let apjsValue;
    if (isSerializedArrayPropery || isDualInstanceArrayProperty) {
      if (!value) {
        value = new effect.Amaz.Vector();
      }
      // transfer guid in vector to object
      for (let i = 0; i < value.size(); i++) {
        if (value.get(i) instanceof effect.Amaz.Guid) {
          value.set(i, effect.Amaz.AmazingUtil.guidToPointer(value.get(i)));
        } else {
          value.set(i, value.get(i));
        }
      }
      apjsValue = new Array();
      for (let i = 0; i < value.size(); i++) {
        apjsValue.push(apjs.transferToAPJSObj(value.get(i)));
      }
    } else {
      if (value instanceof effect.Amaz.Guid) {
        value = apjs.transferToAPJSObj(
          effect.Amaz.AmazingUtil.guidToPointer(value)
        );
      }
      apjsValue = apjs.transferToAPJSObj(value);
    }

    if (value2 instanceof effect.Amaz.Guid) {
      value2 = effect.Amaz.AmazingUtil.guidToPointer(value2);
    }
    const apjsValue2 = apjs.transferToAPJSObj(value2);
    if (apjs.isDynamicAsset(obj)) {
      obj = obj.getControl();
    }
    if (
      apjs.isSerializeProperty(obj, methodName) ||
      apjs.isDualInstanceScriptProperty(obj, methodName)
    ) {
      obj[methodName] = apjsValue;
    } else if (apjs.isDualInstanceScriptMethod(obj, methodName)) {
      obj[methodName](apjsValue, apjsValue2);
    } else if (apjs.isJSScriptDualInstanceMethod(obj, methodName)) {
      // transport JSScriptComponent call method
      try {
        obj.getScript().ref[methodName](apjsValue, apjsValue2);
      } catch (e) {
        Amaz.LOGE(apjs.APTAG, 'call JSScriptComponent method ' + methodName + ' failed! ' + e.toString());
      }
    }
  }

  onSetProperty(obj, key, value) {
    const apjsObj = apjs.transferToAPJSObj(obj);
    const apjsValue = apjs.transferToAPJSObj(value);


    if (apjsObj && key) {
      if (typeof apjsObj.trySetProperty === 'function') {
        if (apjsObj.trySetProperty(key, apjsValue)) {
          return;
        }
      }
      if (isMultiLayerProperty(key))
      {
        const decodedKey = decodeMultiLayerProperty(key);
        const {realObj, realProperty} = apjs.decodePropertyToAccessor(apjsObj, decodedKey);
        if (realObj && realProperty && realProperty in realObj)
        {
          realObj[realProperty] = apjsValue;
        }
      } else if (
        this.propertyBridge &&
        this.propertyBridge.isSpecialProperty(apjsObj, key)
      ) {
        this.propertyBridge.setProperty(apjsObj, key, apjsValue);
      }
      else {
        apjsObj[key] = apjsValue;
      }
    }
  }

  onSetPropertyWithSharedMemory(params) {
    for (let i = 0; i < params.length; i += 3) {
      this.onSetProperty(params[i], params[i + 1], params[i + 2]);
    }
  }

  onGetProperty(obj, propertyName) {
    const apjsObj = apjs.transferToAPJSObj(obj);
    if (typeof apjsObj.tryGetProperty === 'function') {
      const val = apjsObj.tryGetProperty(propertyName);
      if (typeof val !== 'symbol') {
        return apjs.getNativeFromObj(val);
      }
    }
    if (isMultiLayerProperty(propertyName))
    {
      const decodedKey = decodeMultiLayerProperty(propertyName);
      const {realObj, realProperty} = apjs.decodePropertyToAccessor(apjsObj, decodedKey);
      if (realObj && realProperty && realProperty in realObj)
      {
        return apjs.getNativeFromObj(realObj[realProperty]);
      }
    } else if (
      this.propertyBridge &&
      this.propertyBridge.isSpecialProperty(apjsObj, propertyName)
    ) {
      return apjs.getNativeFromObj(this.propertyBridge.getProperty(apjsObj, propertyName));
    } else {
      return apjs.getNativeFromObj(apjsObj[propertyName]);
    }
  }

  onRelease() {
    for (let i = 0; i < this.allDynamicComponents.length; i++) {
      const customComp = this.allDynamicComponents[i];
      if (customComp && typeof customComp.onRelease === 'function')
      {
        customComp.onRelease();
      }
    }
  }

  onSharedMemoryReady(arrayBuffer) {
    if (!this.sharedMemoryReader) {
      this.sharedMemoryReader = new apjs.SharedMemoryReader(arrayBuffer);
    }
    this.sharedMemoryReader.reset();
    const paramCount = this.sharedMemoryReader.readUInt32();
    const params = new Array();
    for (let i = 0; i < paramCount; i++) {
      params.push(this.sharedMemoryReader.readVariant());
    }
    this.onSetPropertyWithSharedMemory(params);
  }

  createSubsystem(systemName) {
    const systemCtor = apjs.getSystemScriptCtorByName(systemName);
    if (systemCtor !== undefined) {
      const system = new systemCtor();
      system.scene = this.scene;
      if (system.updateOrder === undefined) {
        system.updateOrder = 1000;
      }
      this.subsystemNameToDataMap.set(systemName, {
        instance: system,
        components: new Set(),
      });
      this.subsystems.push(system);
      // TODO: check order
      if (this.systemInited) {
        if(system.hasOwnProperty('jsScript')){
          system.jsScript = this.script;
        }
        system.onInit();
      }
      if (this.systemStarted) {
        system.onStart();
      }
      // for (const component of this.cacheAddedComponents) {
      //   system.onComponentAdded(component);
      // }
      return true;
    } else {
      console.error(systemName + ' is not registered!!');
      return false;
    }
  }

  ensureSubsystem(component) {
    const dependentSystems = apjs.getDependentSystems(component);
    if (dependentSystems) {
      let newSystemCreated = false;
      for (const systemName of dependentSystems) {
        if ([...this.subsystemNameToDataMap.keys()].includes(systemName)) {
          this.subsystemNameToDataMap.get(systemName).components.add(component);
        } else {
          const createSuccess = this.createSubsystem(systemName);
          newSystemCreated = newSystemCreated || createSuccess;
          if (createSuccess) {
            const systemData = this.subsystemNameToDataMap.get(systemName);
            systemData.components.add(component);
            // TODO: chack order
            for (const component of this.cacheAddedComponents) {
              systemData.instance.onComponentAdded(component);
            }
          }
        }
      }
      if (newSystemCreated) {
        this.subsystems.sort((a, b) => {
          return a.updateOrder - b.updateOrder;
        });
      }
    }
  }

  removeSubsystemIfUnused(component) {
    const dependentSystems = apjs.getDependentSystems(component);
    if (dependentSystems) {
      for (const systemName of dependentSystems) {
        const subsystemData = this.subsystemNameToDataMap.get(systemName);
        if (subsystemData) {
          subsystemData.components.delete(component);
          if (subsystemData.components.size === 0) {
            this.subsystems.splice(0, 1, subsystemData.instance);
            subsystemData.instance = null;
            this.subsystemNameToDataMap.delete(systemName);
          }
        }
      }
    }
  }

  checkAndInitMixEnableFlag() {
    let sdkVersion = effect.Amaz.VERSION;
    sdkVersion = sdkVersion.replace(/\./g, '');
    this._sdkVersionNum = parseInt(sdkVersion);

    if (this._sdkVersionNum >= 1990)
    {
      this.isMixEnable = this.scene.isMixEnable();
    }
  }

  updateAudioDetectorBuilderAvailable() {
    try {
      apjs.AudioDetectorBuilder.isAvailable = false;
    } catch (e) {
      void e;
    }
  }

  checkAndCreateSubSystem() {
    const config = this.scene.config;
    const listStr = config.get('APJSSystemList');
    if (listStr && typeof listStr === 'string' && listStr.length > 0) {
      const list = listStr.split(',');
      const loadedSystemList = [...this.subsystemNameToDataMap.keys()];
      let newSystemCreated = false;
      for (const systemName of list) {
        if (!loadedSystemList.includes(systemName)) {
          this.createSubsystem(systemName);
          newSystemCreated = true;
        }
      }
      if (newSystemCreated) {
        this.subsystems.sort((a, b) => {
          return a.updateOrder - b.updateOrder;
        });
      }
      this.script.handleComponentName(JSScriptComponentType);
    }
  }

  dynamicComponentOnCall(comp, methodName, optionalArg) {
    try {
      comp[methodName](optionalArg);
    } catch (e) {
      if (comp.printError) {
        comp.printError(e);
      } else {
        // RAW Logic;
        throw e;
      }
    }
  }
}

exports.AmazingProRuntime = AmazingProRuntime;
