import SwiftUI

struct FolderMenuItem: View {
    let node: DocumentListViewModel.FolderNode
    let action: (UUID) -> Void

    var body: some View {
        if node.children?.isEmpty ?? true {
            Button(action: { action(node.folder.id) }) {
                Label(node.name, systemImage: node.folder.protected ? "lock.fill" : "folder")
            }
        } else {
            Menu(node.name) {
                ForEach(node.children!) { child in
                    FolderMenuItem(node: child, action: action)
                }
            }
        }
    }
}
