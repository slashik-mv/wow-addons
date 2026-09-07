function getRandomPicture(usedImageIndices, selectedImageIndex)
    local images = SlashikRaidBreakTimeImages
    local imageCount = #images
    if imageCount == 0 then return nil end

    if type(selectedImageIndex) == "number" and selectedImageIndex >= 1 and selectedImageIndex <= imageCount then
        return selectedImageIndex, images.imageFolder .. images[selectedImageIndex]
    end

    local availableImageIndices = {}
    for imageIndex = 1, imageCount do
        if not usedImageIndices or not usedImageIndices[imageIndex] then
            table.insert(availableImageIndices, imageIndex)
        end
    end

    if #availableImageIndices == 0 then return nil end

    local imageIndex = availableImageIndices[math.random(#availableImageIndices)]
    return imageIndex, images.imageFolder .. images[imageIndex]
end
