import Foundation

enum StoreReader {
    struct Loaded<Value> {
        let value: Value
        let data: Data
        let url: URL
    }

    /// Read the backup only when the primary cannot be read or decoded.
    static func firstValid<Value: Decodable>(
        _ type: Value.Type,
        urls: [URL],
        decoder: JSONDecoder,
        readData: (URL) throws -> Data = { try Data(contentsOf: $0) }
    ) -> Loaded<Value>? {
        for url in urls {
            guard let data = try? readData(url),
                  let value = try? decoder.decode(type, from: data) else { continue }
            return Loaded(value: value, data: data, url: url)
        }
        return nil
    }
}
