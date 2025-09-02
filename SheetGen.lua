-- GenSpriteSheet (4 direções ao mesmo tempo)

local spr = app.activeSprite
if not spr then return app.alert("Nenhum sprite aberto!") end

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
