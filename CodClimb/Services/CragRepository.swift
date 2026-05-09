import Foundation

enum CragRepositoryError: Error {
    case resourceMissing
}

struct CragRepository {
    static func loadAll() throws -> [Crag] {
        guard let url = Bundle.main.url(forResource: "crags", withExtension: "json") else {
            throw CragRepositoryError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Crag].self, from: data)
    }
}
