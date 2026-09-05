import Foundation
import SwiftUI

public struct TabItem: Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var url: String
    public var isPrivate: Bool
    public var snapshot: UIImage?
    
    public init(id: UUID = UUID(), title: String = "Nuova pagina", url: String = "https://www.google.com", isPrivate: Bool = false, snapshot: UIImage? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.isPrivate = isPrivate
        self.snapshot = snapshot
    }
}
