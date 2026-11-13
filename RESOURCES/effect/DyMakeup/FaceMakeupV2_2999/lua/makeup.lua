local exports = exports or {}
local makeup = makeup or {}
makeup.__index = makeup

function makeup.new(construct, ...)
    local self = setmetatable({}, makeup)
    self.constructor(self)
    return self
end

--lips intensity
local Unify_lips = 0
local lips_male_intensity = 0.0
local lips_female_intensity = 0.0

--brusher intensity
local Unify_brusher = 0
local brusher_female_intensity = 0.0
local brusher_male_intensity = 0.0

--facial intensity
local Unify_facial = 0
local facial_intensity = 0.0

local teeth_intensity = 0.0

--eye intensity
local Unify_eyepart = 0
local eye_female_01_intensity = 0.0
local eye_male_01_intensity = 0.0

function makeup:constructor()
    self.makeupRenderers = {}
    self.makeupEntity = {}
    self.texPath = {}

    self.forceExpressionDetectCounter = 0;
    self.forceExpressionDetectFlag = false;

    self.lipsExcluded = false;
    self.facialExcluded = false;
    self.teethExcluded = false;
    self.blushExcluded = false;
    self.eyepartExcluded = false;

    self.lipsVisibleDirty = false
    self.facialVisibleDirty = false
    self.teethVisibleDirty = false
    self.blushVisibleDirty = false
    self.eyepartVisibleDirty = false

    self.lipsTags = {
        ["lips_keypoint+2999"] = true,
        ["mouth_part+2997"] = true,
        ["mouth_part+2988"] = true,
        ["mouth_part+2987"] = true,
        ["mouth_part+2986"] = true,
        ["mouth_part+2985"] = true,
    }
    self.teethTags = {
        ["teeth+2993"] = true,
    }
    self.facialTags = {
        ["mask+2995"] = true,
        ["mask+2992"] = true,
        ["mask+2991"] = true,
        ["mask+2999"] = true,
        ["mask+2989"] = true,
    }
    self.blushTags = {
        ["mask+2998"] = true,
        ["mask+2996"] = true,
        ["mask+2984"] = true,
        ["mask+2983"] = true,
        ["mask+2982"] = true,
        ["mask+2981"] = true,
    }

    self.eyepartTags = {
        ["eye_part+2979"] = true,
        ["eye_part+2980"] = true
    }
end

function makeup:onComponentAdded(sys, comp)
    if comp:isInstanceOf('EffectFaceMakeup') then
        self.makeupEntity[comp.entity.name] = comp.entity
        self.makeupRenderers[comp.entity.name] = comp.entity:getComponent('MeshRenderer')
        self.texPath[comp.entity.name] = {}
        comp:setFaceUniform('opacity', 0, 1.0);
    end
end

function makeup:onComponentRemoved(sys, comp)
    if comp:isInstanceOf('EffectFaceMakeup') then
        self.makeupRenderers[comp.entity.name] = nil
        self.makeupEntity[comp.entity.name] = nil
        self.texPath[comp.entity.name] = nil
    end
end

function makeup:onStart(sys)
    sys:clearAllEventType()
    sys:addEventType(Amaz.BEFEventType.BET_COMPOSER);
    sys:addEventType(Amaz.BEFEventType.BET_EXCLUSIVE);
    sys:addEventType(Amaz.AppEventType.COMPAT_BEF);

    -- disable depth rt
    local outputRT = sys.scene:getOutputRenderTexture()
    outputRT.attachment = Amaz.RenderTextureAttachment.NONE

    -- Asset manager for syncloading
    self.assetMgr = sys.scene.assetMgr
end

function makeup:forceExpressionDetect(forceEnable)
    Amaz.Algorithm.setAlgorithmParamInt("", 'expression_detect_0', 'face_attr_force_detect', forceEnable);
end

function makeup:loadTexture(entityName, key, url)
    local entityTexPath = self.texPath[entityName]
    local tex = nil

    if entityTexPath[key] == nil then
        tex = self.assetMgr:SyncLoad(url)
        entityTexPath[key] = tex
    else
        tex = entityTexPath[key]
    end

    return tex
end

function makeup:enableEntity(entityName)
    local entity = self.makeupEntity[entityName]
    if (not entity.visible) then
        local sharedMat = self.makeupRenderers[entityName].sharedMaterials
        local texPathTable = entity:getComponent('TableComponent').table
        local keys = texPathTable:getVectorKeys()
        local faceIdsSize = entity:getComponent('EffectFaceMakeup').faceIds:size()

        for i = 0, keys:size() - 1 do
            local key = keys:get(i)
            local url = texPathTable:get(key)
            for j = 0, faceIdsSize - 1, 1 do
                local mat = sharedMat:get(j)
                if (mat:getTex(key) == nil) then
                    local tex = self:loadTexture(entityName, key, url)
                    mat:setTex(key, tex)
                end
            end
        end

        self.makeupEntity[entityName].visible = true
    end
end

function makeup:updateMaterialValue(entityName, values)
    if (self.makeupEntity[entityName].visible) then
        local makeupComp = self.makeupEntity[entityName]:getComponent('EffectFaceMakeup')
        makeupComp:setUniform('intensity', 1.0)
        for i = 1, #values do
            makeupComp:setFaceUniform('opacity', i - 1, values[i])
        end
    end
end

function makeup:processEntityVisible(entityName, intensity, vals)
    if intensity == 0.0 then
        self.makeupEntity[entityName].visible = false
    elseif intensity > 0.0 then
        self:enableEntity(entityName)
    end
end

-- male and female share one entity
function makeup:processSharedEntityVisible(entityName, maleIntensity, femaleIntensity, vals)
    if maleIntensity == 0.0 and femaleIntensity == 0.0 then
        self.makeupEntity[entityName].visible = false
    elseif maleIntensity > 0.0 or femaleIntensity > 0.0 then
        self:enableEntity(entityName)
    end
end

function makeup:processEntity(entityName, intensity, vals)
    if intensity > 0.0 then
        self:updateMaterialValue(entityName, vals)
    end
end

-- male and female share one entity
function makeup:processSharedEntity(entityName, maleIntensity, femaleIntensity, vals)
    if maleIntensity > 0.0 or femaleIntensity > 0.0 then
        self:updateMaterialValue(entityName, vals)
    end
end

-- =====================================================================================
-- GCC 文件输入通道（2026-11-02 四轮）—— 与本文件业务无关的通用基础设施
--
-- 背景（analysis/emu_node.txt 实证）：
--   引擎的 composer 节点表是真的（dumpComposerEffectNodes 能看到 Smooth_ALL / Face_ALL …），
--   但「节点变化 → 场景脚本 onEvent」这一跳在 amazing 子场景里是死的：
--   探针 [GCCANY] 记录**任何** event.type，45 秒 0 条。所以无论值发得多对，脚本都收不到。
--   而 [GCCAMAZ] 同时证明 Lua 层 io.open 是真函数。
--   ⇒ 改用"宿主写文件、脚本轮询"的通道：Java 每帧写 <files>/gcc_shape.txt，
--     脚本每 3 帧比对内容，变了就逐行合成一个 composer 事件喂回 onEvent。
--
-- 关键设计：**不复制任何业务数学**。
--   合成事件的对象形状与引擎 ComposerNodeEvent 完全一致（type / args:get(i)），
--   于是 onEvent 里原有的分支、乘数、正负号、互斥清零全部原样生效。
--   我们只换了"值从哪来"，抖音的效果参数一个字节没动。
--
-- 全局只定义一次：四个场景脚本都会 require 这段，谁先加载谁定义。
-- =====================================================================================
if gcc_poll_ev == nil then
    gcc_poll_ev = {
        type = Amaz.BEFEventType.BET_COMPOSER,
        args = { get = function(_, ix)
            if ix == 0 then return gcc_poll_tag end
            if ix == 2 then return gcc_poll_val end
            return nil
        end },
    }
end
if gcc_poll_bind == nil then
    gcc_poll_bind = function(obj, sys, name)
        local paths = {
            "/data/user/0/com.gcc.gate/files/gcc_shape.txt",
            "/data/data/com.gcc.gate/files/gcc_shape.txt",
        }
        obj.__gccTick = (obj.__gccTick or 0) + 1
        -- 探路：文件可能比场景晚到（Java 的 init 在 set_sticker 之后才写完第一版），
        -- 所以失败不能只试一次 —— 每分钟期的第 0 帧重试一次，直到探到为止。
        if obj.__gccPath == nil then
            if obj.__gccProbed ~= nil and (obj.__gccTick % 60) ~= 0 then return end
            obj.__gccProbed = true
            for i = 1, #paths do
                local f = nil
                pcall(function() f = io.open(paths[i], "r") end)
                if f ~= nil then
                    pcall(function() f:close() end)
                    obj.__gccPath = paths[i]
                    break
                end
            end
            Amaz.LOGI("GCCIO", "bind path=" .. tostring(obj.__gccPath))
        end
        if obj.__gccPath == nil then return end
        if obj.__gccTick % 3 ~= 0 then return end
        local f = nil
        pcall(function() f = io.open(obj.__gccPath, "r") end)
        if f == nil then obj.__gccPath = nil; return end
        local raw = ""
        pcall(function() raw = f:read("*a") or "" end)
        pcall(function() f:close() end)
        if raw == obj.__gccRaw then return end
        obj.__gccRaw = raw
        local n = 0
        for line in string.gmatch(raw, "[^\r\n]+") do
            if string.sub(line, 1, 1) ~= "#" then
                local k, v = string.match(line, "^%s*([%w_]+)%s*=%s*(-?%d+%.?%d*)%s*$")
                if k ~= nil and v ~= nil then
                    -- 复用同一个事件对象 + 同两个 upvalue，避免每行都新建 table/闭包。
                    -- 一次快照 60 行 × 4 个脚本 = 240 个对象；在 60fps 的相机里拖滑条
                    -- 每秒会产生上万个短命对象，白白喂 GC。这里降到每次轮询 0 个。
                    gcc_poll_tag = k
                    gcc_poll_val = tonumber(v)
                    pcall(obj.onEvent, obj, sys, gcc_poll_ev)
                    n = n + 1
                end
            end
        end
        if n > 0 then
            -- 日志限流：拖滑条时每秒会触发几十次 applied，全打会把 logcat 刷满
            -- （真机上还费电）。前 20 条留作证据，之后只写 ack 不打日志。
            obj.__gccLog = (obj.__gccLog or 0) + 1
            if obj.__gccLog <= 20 then
                Amaz.LOGI("GCCIO", "applied " .. n .. " #" .. obj.__gccLog)
            end
            -- ack：把"脚本侧确实收到并转交给 onEvent"这件事写给宿主看。
            -- 用独立文件、不复用 gcc_shape.txt，避免读写方向互相干扰。
            -- 宿主每 500ms 读一次，直接显示在屏幕 HUD 的 CH 一行。
            local ackp = string.match(obj.__gccPath, "^(.*/)") .. "gcc_ack_" .. tostring(name) .. ".txt"
            pcall(function()
                local ackf = io.open(ackp, "w")
                if ackf ~= nil then
                    ackf:write(obj.__gccTick .. ":" .. n)
                    ackf:close()
                end
            end)
        end
    end
end

function makeup:onUpdate(sys, deltaTime)
    -- ★ 文件输入通道（见文件头注释）：必须最先跑
    gcc_poll_bind(self, sys, "makeup")
    -- GCC 场景探针：每 150 帧（约 4 秒）打一次"脚本此刻真正持有的强度"，
    -- 用于真机上判定"值到没到脚本"和"脚本有没有吃进去"，不依赖任何事件。
    self.__scn = (self.__scn or 0) + 1
    if self.__scn % 150 == 0 then
        Amaz.LOGI("GCCSCN", "lipsF=" .. tostring(lips_female_intensity)
                .. " lipsM=" .. tostring(lips_male_intensity)
                .. " uLips=" .. tostring(Unify_lips)
                .. " blushF=" .. tostring(brusher_female_intensity)
                .. " blushM=" .. tostring(brusher_male_intensity)
                .. " uBlush=" .. tostring(Unify_brusher)
                .. " facial=" .. tostring(facial_intensity)
                .. " uFacial=" .. tostring(Unify_facial))
    end
    local aeAlgResult = Amaz.Algorithm.getAEAlgorithmResult()
    if aeAlgResult ~= nil then
        local faceNum = aeAlgResult:getFaceCount()
        local faceAttrNum = aeAlgResult:getFaceAttributeCount()
        if faceNum > 0 then
            local lip_male_vals = {}
            local lip_female_vals = {}
            local lipds_vals = {}
            local lipfg_vals = {}
            local lipxy_vals = {}
            local lipyq_vals = {}
            local brusher_male_vals = {}
            local brusher_female_vals = {}
            local brusherds_vals = {}
            local brusherqw_vals = {}
            local brushertc_vals = {}
            local brusherzx_vals = {}
            local facial_vals = {}
            local teeth_vals = {}
            local eye_female_01_vals = {}
            local eye_male_01_vals = {}

            for i = 0, faceNum - 1 do
                local occlusion = aeAlgResult:getFaceOcclusion(i)
                if occlusion ~= nil and occlusion.prob >= 0.8 then
                    -- face occluded, make opacity 0
                    table.insert(facial_vals, 0.0)
                    table.insert(teeth_vals, 0.0)
                    table.insert(lip_female_vals, 0.0)
                    table.insert(brusher_female_vals, 0.0)
                    table.insert(lipds_vals, 0.0)
                    table.insert(lipfg_vals, 0.0)
                    table.insert(lipxy_vals, 0.0)
                    table.insert(lipyq_vals, 0.0)
                    table.insert(brusherds_vals, 0.0)
                    table.insert(brusherqw_vals, 0.0)
                    table.insert(brushertc_vals, 0.0)
                    table.insert(brusherzx_vals, 0.0)
                    table.insert(lip_male_vals, 0.0)
                    table.insert(brusher_male_vals, 0.0)
                    local boyProb = -1.0
                    if i < faceAttrNum then
                        local attr = aeAlgResult:getFaceAttributeInfo(i)
                        if attr ~= nil then
                            boyProb = attr.boyProb
                        end
                    end
                    if boyProb < 0.4 then
                        -- female
                        table.insert(eye_female_01_vals, eye_female_01_intensity)
                        table.insert(eye_male_01_vals, 0.0)
                    else
                        -- male
                        table.insert(eye_female_01_vals, 0.0)
                        table.insert(eye_male_01_vals, eye_male_01_intensity)
                    end
                else
                    local boyProb = -1.0
                    if i < faceAttrNum then
                        local attr = aeAlgResult:getFaceAttributeInfo(i)
                        if attr ~= nil then
                            boyProb = attr.boyProb
                        end
                    end
                    table.insert(facial_vals, facial_intensity)
                    table.insert(teeth_vals, teeth_intensity)
                    if boyProb < 0.4 then
                        -- female
                        table.insert(lip_female_vals, lips_female_intensity)
                        table.insert(brusher_female_vals, brusher_female_intensity)
                        table.insert(lipds_vals, lips_female_intensity)
                        table.insert(lipfg_vals, lips_female_intensity)
                        table.insert(lipxy_vals, lips_female_intensity)
                        table.insert(lipyq_vals, lips_female_intensity)
                        table.insert(brusherds_vals, brusher_female_intensity)
                        table.insert(brusherqw_vals, brusher_female_intensity)
                        table.insert(brushertc_vals, brusher_female_intensity)
                        table.insert(brusherzx_vals, brusher_female_intensity)
                        table.insert(lip_male_vals, 0.0)
                        table.insert(brusher_male_vals, 0.0)
                        table.insert(eye_female_01_vals, eye_female_01_intensity)
                        table.insert(eye_male_01_vals, 0.0)
                    else
                        -- male
                        table.insert(lip_male_vals, lips_male_intensity)
                        table.insert(brusher_male_vals, brusher_male_intensity)
                        table.insert(lipds_vals, lips_male_intensity)
                        table.insert(lipfg_vals, lips_male_intensity)
                        table.insert(lipxy_vals, lips_male_intensity)
                        table.insert(lipyq_vals, lips_male_intensity)
                        table.insert(brusherds_vals, brusher_male_intensity)
                        table.insert(brusherqw_vals, brusher_male_intensity)
                        table.insert(brushertc_vals, brusher_male_intensity)
                        table.insert(brusherzx_vals, brusher_male_intensity)
                        table.insert(lip_female_vals, 0.0)
                        table.insert(brusher_female_vals, 0.0)
                        table.insert(eye_female_01_vals, 0.0)
                        table.insert(eye_male_01_vals, eye_male_01_intensity)
                    end
                end
            end
            -- update visible

            if self.facialVisibleDirty then
                self.facialVisibleDirty = false
                if not self.facialExcluded then
                    if Unify_facial == 0 then
                        self.makeupEntity['mask2992_entity'].visible = false
                        self.makeupEntity['mask2991_entity'].visible = false
                        self.makeupEntity['mask2990_entity'].visible = false
                        self.makeupEntity['mask2989_entity'].visible = false
                        self:processEntityVisible("mask2995_entity", facial_intensity, facial_vals)
                    elseif Unify_facial == 1 then
                        self.makeupEntity['mask2995_entity'].visible = false
                        self.makeupEntity['mask2991_entity'].visible = false
                        self.makeupEntity['mask2990_entity'].visible = false
                        self.makeupEntity['mask2989_entity'].visible = false
                        self:processEntityVisible("mask2992_entity", facial_intensity, facial_vals)
                    elseif Unify_facial == 2 then
                        self.makeupEntity['mask2995_entity'].visible = false
                        self.makeupEntity['mask2992_entity'].visible = false
                        self.makeupEntity['mask2990_entity'].visible = false
                        self.makeupEntity['mask2989_entity'].visible = false
                        self:processEntityVisible("mask2991_entity", facial_intensity, facial_vals)
                    elseif Unify_facial == 3 then
                        self.makeupEntity['mask2995_entity'].visible = false
                        self.makeupEntity['mask2992_entity'].visible = false
                        self.makeupEntity['mask2991_entity'].visible = false
                        self.makeupEntity['mask2989_entity'].visible = false
                        self:processEntityVisible("mask2990_entity", facial_intensity, facial_vals)
                    elseif Unify_facial == 4 then
                        self.makeupEntity['mask2995_entity'].visible = false
                        self.makeupEntity['mask2992_entity'].visible = false
                        self.makeupEntity['mask2991_entity'].visible = false
                        self.makeupEntity['mask2990_entity'].visible = false
                        self:processEntityVisible("mask2989_entity", facial_intensity, facial_vals)
                    end
                else
                    self.makeupEntity['mask2995_entity'].visible = false
                    self.makeupEntity['mask2992_entity'].visible = false
                    self.makeupEntity['mask2991_entity'].visible = false
                    self.makeupEntity['mask2990_entity'].visible = false
                    self.makeupEntity['mask2989_entity'].visible = false
                end
            end
            if self.teethVisibleDirty then
                self.teethVisibleDirty = false
                if not self.teethExcluded then
                    self:processEntityVisible('teeth2993_entity', teeth_intensity, teeth_vals)
                else
                    self.makeupEntity['teeth2993_entity'].visible = false
                end
            end
            if self.lipsVisibleDirty then
                self.lipsVisibleDirty = false
                if not self.lipsExcluded then
                    if Unify_lips == 0 then
                        self.makeupEntity['mouth_part2988_entity'].visible = false
                        self.makeupEntity['mouth_part2987_entity'].visible = false
                        self.makeupEntity['mouth_part2986_entity'].visible = false
                        self.makeupEntity['mouth_part2985_entity'].visible = false

                        self:processEntityVisible('lips_keypoint2999_entity', lips_male_intensity, lip_male_vals)
                        self:processEntityVisible('mouth_part2997_entity', lips_female_intensity, lip_female_vals)
                    elseif Unify_lips == 1 then
                        self.makeupEntity['lips_keypoint2999_entity'].visible = false
                        self.makeupEntity['mouth_part2997_entity'].visible = false
                        self.makeupEntity['mouth_part2987_entity'].visible = false
                        self.makeupEntity['mouth_part2986_entity'].visible = false
                        self.makeupEntity['mouth_part2985_entity'].visible = false

                        self:processSharedEntityVisible('mouth_part2988_entity', lips_male_intensity,
                            lips_female_intensity, lipds_vals)
                    elseif Unify_lips == 2 then
                        self.makeupEntity['lips_keypoint2999_entity'].visible = false
                        self.makeupEntity['mouth_part2997_entity'].visible = false
                        self.makeupEntity['mouth_part2988_entity'].visible = false
                        self.makeupEntity['mouth_part2986_entity'].visible = false
                        self.makeupEntity['mouth_part2985_entity'].visible = false

                        self:processSharedEntityVisible('mouth_part2987_entity', lips_male_intensity,
                            lips_female_intensity, lipfg_vals)
                    elseif Unify_lips == 3 then
                        self.makeupEntity['lips_keypoint2999_entity'].visible = false
                        self.makeupEntity['mouth_part2997_entity'].visible = false
                        self.makeupEntity['mouth_part2988_entity'].visible = false
                        self.makeupEntity['mouth_part2987_entity'].visible = false
                        self.makeupEntity['mouth_part2985_entity'].visible = false

                        self:processSharedEntityVisible('mouth_part2986_entity', lips_male_intensity,
                            lips_female_intensity, lipxy_vals)
                    elseif Unify_lips == 4 then
                        self.makeupEntity['lips_keypoint2999_entity'].visible = false
                        self.makeupEntity['mouth_part2997_entity'].visible = false
                        self.makeupEntity['mouth_part2988_entity'].visible = false
                        self.makeupEntity['mouth_part2987_entity'].visible = false
                        self.makeupEntity['mouth_part2986_entity'].visible = false

                        self:processSharedEntityVisible('mouth_part2985_entity', lips_male_intensity,
                            lips_female_intensity, lipyq_vals)
                    end
                else
                    self.makeupEntity['lips_keypoint2999_entity'].visible = false
                    self.makeupEntity['mouth_part2997_entity'].visible = false
                    self.makeupEntity['mouth_part2988_entity'].visible = false
                    self.makeupEntity['mouth_part2987_entity'].visible = false
                    self.makeupEntity['mouth_part2986_entity'].visible = false
                    self.makeupEntity['mouth_part2985_entity'].visible = false
                end
            end
            if self.blushVisibleDirty then
                self.blushVisibleDirty = false
                if not self.blushExcluded then
                    if Unify_brusher == 0 then
                        self.makeupEntity['mask2984_entity'].visible = false
                        self.makeupEntity['mask2983_entity'].visible = false
                        self.makeupEntity['mask2982_entity'].visible = false
                        self.makeupEntity['mask2981_entity'].visible = false

                        self:processEntityVisible('mask2998_entity', brusher_male_intensity, brusher_male_vals)
                        self:processEntityVisible("mask2996_entity", brusher_female_intensity, brusher_female_vals)
                    elseif Unify_brusher == 1 then
                        self.makeupEntity['mask2998_entity'].visible = false
                        self.makeupEntity['mask2996_entity'].visible = false
                        self.makeupEntity['mask2983_entity'].visible = false
                        self.makeupEntity['mask2982_entity'].visible = false
                        self.makeupEntity['mask2981_entity'].visible = false

                        self:processSharedEntityVisible('mask2984_entity', brusher_male_intensity,
                            brusher_female_intensity, brusherds_vals)
                    elseif Unify_brusher == 2 then
                        self.makeupEntity['mask2998_entity'].visible = false
                        self.makeupEntity['mask2996_entity'].visible = false
                        self.makeupEntity['mask2984_entity'].visible = false
                        self.makeupEntity['mask2982_entity'].visible = false
                        self.makeupEntity['mask2981_entity'].visible = false

                        self:processSharedEntityVisible('mask2983_entity', brusher_male_intensity,
                            brusher_female_intensity, brusherqw_vals)
                    elseif Unify_brusher == 3 then
                        self.makeupEntity['mask2998_entity'].visible = false
                        self.makeupEntity['mask2996_entity'].visible = false
                        self.makeupEntity['mask2984_entity'].visible = false
                        self.makeupEntity['mask2983_entity'].visible = false
                        self.makeupEntity['mask2981_entity'].visible = false

                        self:processSharedEntityVisible('mask2982_entity', brusher_male_intensity,
                            brusher_female_intensity, brushertc_vals)
                    elseif Unify_brusher == 4 then
                        self.makeupEntity['mask2998_entity'].visible = false
                        self.makeupEntity['mask2996_entity'].visible = false
                        self.makeupEntity['mask2984_entity'].visible = false
                        self.makeupEntity['mask2983_entity'].visible = false
                        self.makeupEntity['mask2982_entity'].visible = false

                        self:processSharedEntityVisible('mask2981_entity', brusher_male_intensity,
                            brusher_female_intensity, brusherzx_vals)
                    end
                else
                    self.makeupEntity['mask2998_entity'].visible = false
                    self.makeupEntity['mask2996_entity'].visible = false
                    self.makeupEntity['mask2984_entity'].visible = false
                    self.makeupEntity['mask2983_entity'].visible = false
                    self.makeupEntity['mask2982_entity'].visible = false
                    self.makeupEntity['mask2981_entity'].visible = false
                end
            end

            if self.eyepartVisibleDirty then
                self.eyepartVisibleDirty = false
                if not self.eyepartExcluded then
                    if Unify_eyepart == 0 then
                        self:processEntityVisible('eye_part2979_entity', eye_female_01_intensity, eye_female_01_vals)
                        self:processEntityVisible('eye_part2980_entity', eye_male_01_intensity, eye_male_01_vals)
                    end
                else
                    self.makeupEntity['eye_part2979_entity'].visible = false
                    self.makeupEntity['eye_part2980_entity'].visible = false
                end
            end
            -- update intenisty
            if not self.facialExcluded then
                if Unify_facial == 0 then
                    self:processEntity("mask2995_entity", facial_intensity, facial_vals)
                elseif Unify_facial == 1 then
                    self:processEntity("mask2992_entity", facial_intensity, facial_vals)
                elseif Unify_facial == 2 then
                    self:processEntity("mask2991_entity", facial_intensity, facial_vals)
                elseif Unify_facial == 3 then
                    self:processEntity("mask2990_entity", facial_intensity, facial_vals)
                elseif Unify_facial == 4 then
                    self:processEntity("mask2989_entity", facial_intensity, facial_vals)
                end
            end

            if not self.teethExcluded then
                self:processEntity('teeth2993_entity', teeth_intensity, teeth_vals)
            end

            if not self.lipsExcluded then
                if Unify_lips == 0 then
                    self:processEntity('lips_keypoint2999_entity', lips_male_intensity, lip_male_vals)
                    self:processEntity('mouth_part2997_entity', lips_female_intensity, lip_female_vals)
                elseif Unify_lips == 1 then
                    self:processSharedEntity('mouth_part2988_entity', lips_male_intensity, lips_female_intensity,
                        lipds_vals)
                elseif Unify_lips == 2 then
                    self:processSharedEntity('mouth_part2987_entity', lips_male_intensity, lips_female_intensity,
                        lipfg_vals)
                elseif Unify_lips == 3 then
                    self:processSharedEntity('mouth_part2986_entity', lips_male_intensity, lips_female_intensity,
                        lipxy_vals)
                elseif Unify_lips == 4 then
                    self:processSharedEntity('mouth_part2985_entity', lips_male_intensity, lips_female_intensity,
                        lipyq_vals)
                end
            end

            if not self.blushExcluded then
                if Unify_brusher == 0 then
                    self:processEntity('mask2998_entity', brusher_male_intensity, brusher_male_vals)
                    self:processEntity("mask2996_entity", brusher_female_intensity, brusher_female_vals)
                elseif Unify_brusher == 1 then
                    self:processSharedEntity('mask2984_entity', brusher_male_intensity, brusher_female_intensity,
                        brusherds_vals)
                elseif Unify_brusher == 2 then
                    self:processSharedEntity('mask2983_entity', brusher_male_intensity, brusher_female_intensity,
                        brusherqw_vals)
                elseif Unify_brusher == 3 then
                    self:processSharedEntity('mask2982_entity', brusher_male_intensity, brusher_female_intensity,
                        brushertc_vals)
                elseif Unify_brusher == 4 then
                    self:processSharedEntity('mask2981_entity', brusher_male_intensity, brusher_female_intensity,
                        brusherzx_vals)
                end
            end

            if not self.eyepartExcluded then
                if Unify_eyepart == 0 then
                    self:processEntity('eye_part2979_entity', eye_female_01_intensity, eye_female_01_vals)
                    self:processEntity('eye_part2980_entity', eye_male_01_intensity, eye_male_01_vals)
                end
            end


            --- Toggle force expression detect
            if self.forceExpressionDetectFlag and self.forceExpressionDetectCounter < 2 then
                self.forceExpressionDetectCounter = self.forceExpressionDetectCounter + 1
            else
                self:forceExpressionDetect(false)
                self.forceExpressionDetectFlag = false
            end
        end
    end
end

function makeup:onEvent(sys, event)
    if event.type == Amaz.BEFEventType.BET_COMPOSER then
        local tag = event.args:get(0)
        local percentage = event.args:get(2)
        -- print('composerKey is'..composerKey)
        -- print('value is'..value)
        if tag == "Lips_Male" then
            Unify_lips = 0
            lips_male_intensity = percentage
            self.lipsVisibleDirty = true
        elseif tag == "Lips_female" then
            Unify_lips = 0
            lips_female_intensity = percentage
            self.lipsVisibleDirty = true
        elseif tag == "Lips_Male_ds" then
            Unify_lips = 1
            lips_male_intensity = percentage
            self.lipsVisibleDirty = true
        elseif tag == "Lips_Female_ds" then
            Unify_lips = 1
            lips_female_intensity = percentage
            self.lipsVisibleDirty = true
        elseif tag == "Lips_Male_fg" then
            Unify_lips = 2
            lips_male_intensity = percentage
            self.lipsVisibleDirty = true
        elseif tag == "Lips_Female_fg" then
            Unify_lips = 2
            lips_female_intensity = percentage
            self.lipsVisibleDirty = true
        elseif tag == "Lips_Male_xy" then
            Unify_lips = 3
            lips_male_intensity = percentage
            self.lipsVisibleDirty = true
        elseif tag == "Lips_Female_xy" then
            Unify_lips = 3
            lips_female_intensity = percentage
            self.lipsVisibleDirty = true
        elseif tag == "Lips_Male_yq" then
            Unify_lips = 4
            lips_male_intensity = percentage
            self.lipsVisibleDirty = true
        elseif tag == "Lips_Female_yq" then
            Unify_lips = 4
            lips_female_intensity = percentage
            self.lipsVisibleDirty = true
        elseif tag == "Blusher_female" then
            Unify_brusher = 0
            brusher_female_intensity = percentage
            self.blushVisibleDirty = true
        elseif tag == "Blusher_Male" then
            Unify_brusher = 0
            brusher_male_intensity = percentage * 0.6
            self.blushVisibleDirty = true
        elseif tag == "Blusher_Female_ds" then
            Unify_brusher = 1
            brusher_female_intensity = percentage
            self.blushVisibleDirty = true
        elseif tag == "Blusher_Male_ds" then
            Unify_brusher = 1
            brusher_male_intensity = percentage
            self.blushVisibleDirty = true
        elseif tag == "Blusher_Female_qw" then
            Unify_brusher = 2
            brusher_female_intensity = percentage
            self.blushVisibleDirty = true
        elseif tag == "Blusher_Male_qw" then
            Unify_brusher = 2
            brusher_male_intensity = percentage
            self.blushVisibleDirty = true
        elseif tag == "Blusher_Female_tc" then
            Unify_brusher = 3
            brusher_female_intensity = percentage
            self.blushVisibleDirty = true
        elseif tag == "Blusher_Male_tc" then
            Unify_brusher = 3
            brusher_male_intensity = percentage
            self.blushVisibleDirty = true
        elseif tag == "Blusher_Female_zx" then
            Unify_brusher = 4
            brusher_female_intensity = percentage
            self.blushVisibleDirty = true
        elseif tag == "Blusher_Male_zx" then
            Unify_brusher = 4
            brusher_male_intensity = percentage
            self.blushVisibleDirty = true
        elseif tag == "Facial_ALL" then
            Unify_facial = 0
            facial_intensity = percentage
            self.facialVisibleDirty = true
        elseif tag == "Facial_ALL_jl" then
            Unify_facial = 1
            facial_intensity = percentage
            self.facialVisibleDirty = true
        elseif tag == "Facial_ALL_sg" then
            Unify_facial = 2
            facial_intensity = percentage
            self.facialVisibleDirty = true
        elseif tag == "Facial_ALL_yj" then
            Unify_facial = 3
            facial_intensity = percentage
            self.facialVisibleDirty = true
        elseif tag == "Facial_ALL_vl" then
            Unify_facial = 4
            facial_intensity = percentage
            self.facialVisibleDirty = true
        elseif tag == "Teeth_ALL" then
            teeth_intensity = percentage
            self.teethVisibleDirty = true
        elseif tag == "Eye_Female_01" then
            Unify_eyepart = 0
            eye_female_01_intensity = percentage
            self.eyepartVisibleDirty = true
        elseif tag == "Eye_Male_01" then
            Unify_eyepart = 0
            eye_male_01_intensity = percentage
            self.eyepartVisibleDirty = true
        end
    elseif event.type == Amaz.BEFEventType.BET_EXCLUSIVE then
        local exclusiveTag = event.args:get(0);
        local exclusive = event.args:get(1);
        -- print('exclusiveTag is'..exclusiveTag)
        -- print('exclusive is'..tostring(exclusive))
        local EFFECT_EXCLUSIVE_TAG = 'EXCLUSIVE_ALL_PARAM'
        if exclusive then
            if exclusiveTag ~= EFFECT_EXCLUSIVE_TAG then
                if self.lipsTags[exclusiveTag] ~= nil then
                    self.lipsExcluded = true
                    self.lipsVisibleDirty = true
                elseif self.teethTags[exclusiveTag] ~= nil then
                    self.teethExcluded = true
                    self.teethVisibleDirty = true
                elseif self.facialTags[exclusiveTag] ~= nil then
                    self.facialExcluded = true
                    self.facialVisibleDirty = true
                elseif self.blushTags[exclusiveTag] ~= nil then
                    self.blushExcluded = true
                    self.blushVisibleDirty = true
                elseif self.eyepartTags[exclusiveTag] ~= nil then
                    self.eyepartExcluded = true
                    self.eyepartVisibleDirty = true
                end
            end
        else
            self.lipsExcluded = false
            self.facialExcluded = false
            self.teethExcluded = false
            self.blushExcluded = false
            self.eyepartExcluded = false
            self.lipsVisibleDirty = true
            self.facialVisibleDirty = true
            self.teethVisibleDirty = true
            self.blushVisibleDirty = true
            self.eyepartVisibleDirty = true
        end
    elseif event.type == Amaz.AppEventType.COMPAT_BEF then
        if event.args:get(0) == Amaz.BEFEventType.BET_CAMERA_SWITCHED then
            -- make sure expression_detect force detect when camera is switched
            self:forceExpressionDetect(true)
            self.forceExpressionDetectCounter = 0
            self.forceExpressionDetectFlag = true
        end
    end
end

exports.makeup = makeup
return exports
