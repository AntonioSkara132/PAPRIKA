const mapPath = "/home/antonio/Paprika/maps/concepts/paprika_first_view.tmj";
const outputPath = "/home/antonio/Paprika/art/concepts/paprika_first_view_raw.png";
const map = tiled.open(mapPath);
if (!map || !map.isTileMap) {
    tiled.error("Could not open Paprika concept map: " + mapPath);
} else {
    const image = map.toImage();
    if (!image.save(outputPath))
        tiled.error("Could not save Paprika concept image: " + outputPath);
    else
        tiled.log("Saved Paprika concept image: " + outputPath);
}
