-- SheetGen: Exportar e Importar SpriteSheets (4 direções)

local spr = app.activeSprite
if not spr then return app.alert("Nenhum sprite aberto!") end

----------------------------------------------------
-- Função Export
----------------------------------------------------
local function showExportDialog()
  -- ====== Listagem recursiva de opções (igual ao Gen4Frames) ======
  local layerOptions = {}
  local layerRefs = {}

  local function collectOptions(parent, prefix)
    for _, layer in ipairs(parent.layers) do
      if layer.isGroup then
        local opt = "Grupo: " .. prefix .. layer.name
        table.insert(layerOptions, opt)
        layerRefs[opt] = layer
        collectOptions(layer, prefix .. layer.name .. "/")
      elseif layer.isImage then
        local opt = prefix .. layer.name
        table.insert(layerOptions, opt)
        layerRefs[opt] = layer
      end
    end
  end

  collectOptions(spr, "")
  if #layerOptions == 0 then
    return app.alert("Não há layers/grupos para listar.")
  end

  -- ====== UI ======
  local dlg = Dialog("Exportar SpriteSheet")

  dlg:combobox{ id="layerSul",   label="Layer Sul:",   option=layerOptions[1], options=layerOptions }
  dlg:combobox{ id="layerNorte", label="Layer Norte:", option=layerOptions[1], options=layerOptions }
  dlg:combobox{ id="layerLeste", label="Layer Leste:", option=layerOptions[1], options=layerOptions }
  dlg:combobox{ id="layerOeste", label="Layer Oeste:", option=layerOptions[1], options=layerOptions }

  dlg:number{ id="columns", label="Colunas:", text="17" }
  dlg:button{ id="ok", text="Exportar", focus=true }
  dlg:button{ id="cancel", text="Cancelar" }

  dlg:show()
  local data = dlg.data
  if not data.ok then return end

  -- ====== Resolve colunas base ======
  local dirOffsets = { Sul=0, Norte=1, Leste=2, Oeste=3 }

  -- Função para expandir layer/grupo em lista de layers de imagem
  local function expandLayer(key)
    local node = layerRefs[key]
    local out = {}
    local function collect(node)
      if node.isGroup then
        for _, child in ipairs(node.layers) do
          collect(child)
        end
      elseif node.isImage then
        table.insert(out, node)
      end
    end
    if node then collect(node) end
    return out
  end

  local selectedLayers = {
    Sul   = expandLayer(data.layerSul),
    Norte = expandLayer(data.layerNorte),
    Leste = expandLayer(data.layerLeste),
    Oeste = expandLayer(data.layerOeste),
  }

  -- ====== Sheet params ======
  local totalCols = tonumber(data.columns) or 17
  if totalCols < 1 then totalCols = 1 end

  local frameCount = #spr.frames
  if frameCount == 0 then return app.alert("Sprite não possui frames.") end

  local w, h = spr.width, spr.height
  local jump = 4

  -- Calcula linhas necessárias (olhando para a última direção, último frame)
  local lastPos = dirOffsets["Oeste"] + (frameCount-1) * jump
  local rows = math.floor(lastPos / totalCols) + 1

  -- ====== Cria sheet final ======
  local sheet = Image(w * totalCols, h * rows, spr.colorMode)

  -- Para cada direção
  for dir, layers in pairs(selectedLayers) do
    local baseCol = dirOffsets[dir]
    for f = 1, frameCount do
      local posIndex = baseCol + (f-1) * jump
      local col = posIndex % totalCols
      local row = math.floor(posIndex / totalCols)
      local dx = col * w
      local dy = row * h

      for _, layer in ipairs(layers) do
        local cel = layer:cel(f)
        if cel then
          sheet:drawImage(cel.image, Point(dx + cel.position.x, dy + cel.position.y))
        end
      end
    end
  end

  -- Cria novo sprite com 1 frame contendo a sheet
  local newSpr = Sprite(sheet.width, sheet.height, spr.colorMode)
  newSpr:newCel(newSpr.layers[1], 1, sheet, Point(0,0))
  app.activeSprite = newSpr
end

----------------------------------------------------
local function showImportDialog()
  -- Aqui você vai colar o código do Import

local sheetCel = nil
for _, layer in ipairs(spr.layers) do
  local c = layer:cel(1)
  if c then
    sheetCel = c
    break
  end
end
if not sheetCel then
  return app.alert("Não foi possível encontrar uma cel válida na sprite. Verifique a folha aberta.")
end
local sheetImage = sheetCel.image

-- Defaults razoáveis
local defaultCols = 17
local defaultFrameW = math.floor(spr.width / defaultCols)
if defaultFrameW < 1 then defaultFrameW = 32 end
local defaultFrameH = defaultFrameW

-- Dialogo
local dlg = Dialog("Importar SpriteSheet")
dlg:separator{}
dlg:number{ id="columns", label="Colunas da folha (ex: 17):", text=tostring(defaultCols) }
dlg:number{ id="frameW",  label="Largura do frame (px):", text=tostring(defaultFrameW) }
dlg:number{ id="frameH",  label="Altura do frame (px):", text=tostring(defaultFrameH) }

dlg:separator{ text="Informe quantos frames existem em cada direção (inteiro):" }
-- Coloque defaults estimados (máximo possível)
dlg:number{ id="sulCount",  label="Frames Sul:",  text="69" }
dlg:number{ id="norteCount",label="Frames Norte:",text="69" }
dlg:number{ id="lesteCount",label="Frames Leste:",text="69" }
dlg:number{ id="oesteCount",label="Frames Oeste:",text="69" }

dlg:button{ id="ok", text="Importar", focus=true }
dlg:button{ id="cancel", text="Cancelar" }

dlg:show()
local data = dlg.data
if not data.ok then return end

-- Leitura dos valores do usuário
local totalCols = tonumber(data.columns) or 17
local frameW = tonumber(data.frameW) or defaultFrameW
local frameH = tonumber(data.frameH) or defaultFrameH
local sulCount  = math.max(0, math.floor(tonumber(data.sulCount)  or 0))
local norteCount= math.max(0, math.floor(tonumber(data.norteCount)or 0))
local lesteCount= math.max(0, math.floor(tonumber(data.lesteCount)or 0))
local oesteCount= math.max(0, math.floor(tonumber(data.oesteCount)or 0))

-- Validações básicas
if totalCols < 1 then return app.alert("Colunas inválidas.") end
if frameW < 1 or frameH < 1 then return app.alert("Dimensões de frame inválidas.") end
if spr.width % frameW ~= 0 then
  return app.alert("A largura da folha ("..spr.width..") não é múltipla da largura do frame ("..frameW.."). Verifique os valores.")
end
if spr.height % frameH ~= 0 then
  return app.alert("A altura da folha ("..spr.height..") não é múltipla da altura do frame ("..frameH.."). Verifique os valores.")
end

local rows = spr.height / frameH
local totalCells = totalCols * rows

-- Offsets base por direção
local dirOffsets = { Sul=0, Norte=1, Leste=2, Oeste=3 }

-- Determina máximo possível de frames por direção (mínimo entre o informado e o possível)
local function maxPossible(base)
  local lastIndex = totalCells - 1 -- último índice de célula (0-based)
  if base > lastIndex then return 0 end
  return math.floor((lastIndex - base) / 4) + 1
end

local sulMax   = maxPossible(dirOffsets.Sul)
local norteMax = maxPossible(dirOffsets.Norte)
local lesteMax = maxPossible(dirOffsets.Leste)
local oesteMax = maxPossible(dirOffsets.Oeste)

if sulCount  > sulMax  then sulCount  = sulMax  end
if norteCount> norteMax then norteCount= norteMax end
if lesteCount> lesteMax then lesteCount= lesteMax end
if oesteCount> oesteMax then oesteCount= oesteMax end

-- Determina quantos frames o novo sprite terá (o máximo entre as 4 direções)
local newFramesCount = math.max(sulCount, norteCount, lesteCount, oesteCount)
if newFramesCount == 0 then
  return app.alert("Nenhum frame solicitado para importação. Ajuste os valores de contagem por direção.")
end

-- Cria novo sprite com dimensões do frame e modo de cor igual ao sheet
local newSpr = Sprite(frameW, frameH, spr.colorMode)
-- cria frames necessários
while #newSpr.frames < newFramesCount do newSpr:newFrame() end

-- Cria as 4 layers (Sul, Norte, Leste, Oeste) na ordem desejada
local layers = {}
local order = {"Sul","Norte","Leste","Oeste"}
for _, name in ipairs(order) do
  local lyr = newSpr:newLayer()
  lyr.name = name
  table.insert(layers, lyr)
end

-- Função auxiliar: extrai uma sub-imagem (frameW x frameH) da folha na posição (x,y)
local function extractTileImage(x, y)
  local img = Image(frameW, frameH, spr.colorMode)
  -- desenha a folha dentro da imagem temporária deslocada para capturar a região
  img:drawImage(sheetImage, Point(-x, -y))
  return img
end

-- Função que popula uma direção
local function populateDirection(baseCol, count, targetLayerIndex)
  for i = 0, count-1 do
    local posIndex = baseCol + i * 4
    if posIndex >= totalCells then break end
    local col = posIndex % totalCols
    local row = math.floor(posIndex / totalCols)
    local x = col * frameW
    local y = row * frameH
    local tileImg = extractTileImage(x, y)
    local frameNumber = i + 1 -- 1-based no sprite novo
    newSpr:newCel(layers[targetLayerIndex], frameNumber, tileImg, Point(0,0))
  end
end

-- Preenche as 4 direções
populateDirection(dirOffsets.Sul, sulCount,   1) -- Sul → layers[1]
populateDirection(dirOffsets.Norte, norteCount,2) -- Norte → layers[2]
populateDirection(dirOffsets.Leste, lesteCount,3) -- Leste → layers[3]
populateDirection(dirOffsets.Oeste, oesteCount,4) -- Oeste → layers[4]

-- Abre o novo sprite
app.activeSprite = newSpr
app.refresh()
app.alert("Importação concluída! Novo sprite com "..newFramesCount.." frames criado.")
  -- Mantendo a mesma estrutura de função
end

----------------------------------------------------
-- Menu inicial
----------------------------------------------------
local function showMainMenu()
  local dlg = Dialog("SheetGen")
  dlg:button{ id="export", text="Exportar" }
  dlg:button{ id="import", text="Importar" }
  dlg:button{ id="cancel", text="Cancelar" }
  dlg:show()

  local data = dlg.data
  if data.export then
    showExportDialog()
  elseif data.import then
    showImportDialog()
  end
end

----------------------------------------------------
-- Execução
----------------------------------------------------
showMainMenu()
