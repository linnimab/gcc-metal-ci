/**
 * @typedef {import("./ie_package/ie_js/src/compressed/indexLazy").IE} IE
 */

/** @type {IE} */
let IE;
try {
  ({IE} = require('./ie_package/ie_js/src/compressed/indexLazy'));
} catch (err) {
  console.warn('fail to load iejs in sys script');
}

// reference apjs here and register it into iejs
let apjs;
try {
  apjs = require('amazingpro.js');
} catch (err) {
  console.warn('fail to load apjs in iejs sys script');
}

class IEJsEntrySystemScript {
  constructor() {
    this.name = 'IEJsEntrySystemScript';
  }

  /**
   * 在JavaScript的「==」和「!=」中，undefined 和 null 只跟对方相等，且不等于其他任何值
   * 因此可以用「IE != undefined」来代替「IE != undefined && IE != null」
   * 这是一个比较trick的细节，不建议在日常开发中使用
   */
  _isValid(_obj) {
    return _obj !== undefined && _obj !== null;
  }

  /**
   * Check if an IEJs module can be accessed
   * @example
   * ```js
   * _isIEJsModuleValid("IEStateMachineBase", "stateMachines")
   * ```
   */
  _isIEJsModuleValid(_module, _stopLazy = false, ...args) {
    let iejsValid = this._isValid(IE);
    if (!iejsValid) { 
      return false;
    }
    let curModule = IE;

    if(_stopLazy && !IE.isModuleAlreadyLoaded(_module)) {
      return false;
    }

    if (this._isValid(curModule[_module])) {
      curModule = curModule[_module];
    } else {
      return false;
    }

    for (let idx = 0; idx < args.length; idx++) {
      let arg = args[idx];
      if (this._isValid(curModule[arg])) {
        curModule = curModule[arg];
      } else {
        return false;
      }
    }
    return true;
  }

  onInit() {
    if (this._isIEJsModuleValid('ieTimeObj')) {
      IE.ieTimeObj.executeOnInitCallbacks();
    }
  }

  onStart() {
    if (this._isIEJsModuleValid('ieConst')) {
      IE.ieConst.registerVars(this);
    }
    if (this._isIEJsModuleValid('registerAPJs')) {
      IE.registerAPJs(apjs);
    }
    if (this._isIEJsModuleValid('ieTimeObj')) {
      IE.ieTimeObj.executeOnStartCallbacks();
    }
  }
  onUpdate(dt) {
    if (this._isIEJsModuleValid('ieTimeObj')) {
      IE.ieTimeObj.timeSinceEffectStarted += dt;
      IE.ieTimeObj.executeOnUpdateCallbacks(dt);
    }
    if (this._isIEJsModuleValid('IEStateMachineBase', false, 'stateMachines')) {
      // ↓：Update all state machines you have created in your effect.
      for (let entry of IE.IEStateMachineBase.stateMachines.entries()) {
        entry[1].onUpdate(dt);
      }
    }
  }
  onLateUpdate(dt) {
    if (this._isIEJsModuleValid('ieTimeObj')) {
      IE.ieTimeObj.executeOnLateUpdateCallbacks(dt);
    }
  }
  // onComponentAdded(comp) {}

  onEvent(event) {
    if (this._isIEJsModuleValid('ieTimeObj')) {
      IE.ieTimeObj.executeOnEventCallbacks(event);
    }
    if (this._isIEJsModuleValid('IEStateMachineBase', false, 'stateMachines')) {
      // ↓：Check event handling for all state machines you have created in your effect.
      for (let entry of IE.IEStateMachineBase.stateMachines.entries()) {
        entry[1].onEvent(event);
      }
    }
  }
  onDestroy() {
    if (!this._isValid(IE)) {
      return;
    }
    if (this._isIEJsModuleValid('ieTimeObj', true)) {
      IE.ieTimeObj.executeOnDestroyCallbacks();
    }
    if (this._isIEJsModuleValid('ieEventListener', true)) {
      IE.ieEventListener.onDestroy();
    }
    if (this._isIEJsModuleValid('unregisterAPJs', true)) {
      IE.unregisterAPJs();
    }
    if (this._isIEJsModuleValid('ieConst', true)) {
      IE.ieConst.unregisterVars();
    }
    if (this._isIEJsModuleValid('ieConst', true)) {
      this._releaseObjects(IE.ieConst)
    }
    if (this._isIEJsModuleValid('ieTimeObj', true)) {
      this._releaseObjects(IE.ieTimeObj)
    }
    if (this._isIEJsModuleValid('ieEventListener', true)) {
      this._releaseObjects(IE.ieEventListener)
    }
    this._releaseObjects(IE)
  }

  _releaseObjects(_object) {
    if (this._isIEJsModuleValid('isAMEEditingScene', true) && IE.isAMEEditingScene()) {
        // In ame editing scene, the sys script will be reload dynamically, do onDestroy() then do onInit().
        // but IE modules are not reloaded. So we could not release IE modules here.
        return;
    }
    const keys = Object.keys(_object);
    keys.forEach((key) => {
      const descriptor = Object.getOwnPropertyDescriptor(_object, key);
      if (descriptor && (descriptor.writable || descriptor.set)) {
        _object[key] = null;
      }
    });
  }

  onCallBack(...args) {
    if (this._isIEJsModuleValid('ieEventListener')) {
      IE.ieEventListener.activateCallbacks(...args);
    }
  }
}

exports.IEJsEntrySystemScript = IEJsEntrySystemScript;
