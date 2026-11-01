// Glyph of a directory entry by category (files.js): folders lavender, archives amber, images cyan, code green.
import QtQuick
import "../.."
import "../../components"
import "files.js" as F

Glyph {
    property var entry: null
    property string kind: F.category(entry)
    icon: ({ dir: Icons.folderOutline, archive: Icons.fileArchive, image: Icons.fileImage, video: Icons.fileVideo,
             code: Icons.fileCode, link: Icons.fileLink, doc: Icons.fileDoc })[kind] ?? Icons.fileOutline
    color: ({ dir: Theme.files.iconDir, archive: Theme.files.iconArchive, image: Theme.files.iconImage, video: Theme.files.iconImage,
              code: Theme.files.iconCode })[kind] ?? Theme.files.iconDoc
    size: Theme.files.rowIcon
}
