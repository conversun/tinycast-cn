import Foundation

enum DictationLanguage: String, CaseIterable, Identifiable, Sendable {
    case arabic = "Arabic", cantonese = "Cantonese", chinese = "Chinese", czech = "Czech"
    case danish = "Danish", dutch = "Dutch", english = "English", filipino = "Filipino"
    case finnish = "Finnish", french = "French", german = "German", greek = "Greek"
    case hindi = "Hindi", hungarian = "Hungarian", indonesian = "Indonesian", italian = "Italian"
    case japanese = "Japanese", korean = "Korean", macedonian = "Macedonian", malay = "Malay"
    case persian = "Persian", polish = "Polish", portuguese = "Portuguese", romanian = "Romanian"
    case russian = "Russian", spanish = "Spanish", swedish = "Swedish", thai = "Thai"
    case turkish = "Turkish", vietnamese = "Vietnamese"

    var id: Self { self }
}
