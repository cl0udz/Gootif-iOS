import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case notFound
    case serverError(Int)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Unauthorized — check API key"
        case .notFound: return "Not found"
        case .serverError(let code): return "Server error (\(code))"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

enum APIClient {
    static let baseURL = "https://gootif.jianwei.me"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private static func request(path: String, method: String = "GET", queryItems: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents(string: baseURL + path)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.setValue(AppSettings.apiKey, forHTTPHeaderField: "X-API-Key")
        req.timeoutInterval = 15
        return req
    }

    private static func perform(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        switch http.statusCode {
        case 200...299: return data
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default: throw APIError.serverError(http.statusCode)
        }
    }

    static func fetchNotifications(service: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> [GootifNotification] {
        var items: [URLQueryItem] = [
            .init(name: "limit", value: String(limit)),
            .init(name: "offset", value: String(offset)),
        ]
        if let service {
            items.append(.init(name: "service", value: service))
        }
        let req = request(path: "/api/notifications", queryItems: items)
        let data = try await perform(req)
        return try decoder.decode([GootifNotification].self, from: data)
    }

    static func fetchNotification(id: String) async throws -> GootifNotification {
        let req = request(path: "/api/notifications/\(id)")
        let data = try await perform(req)
        return try decoder.decode(GootifNotification.self, from: data)
    }

    static func deleteNotification(id: String) async throws {
        let req = request(path: "/api/notifications/\(id)", method: "DELETE")
        _ = try await perform(req)
    }

    static func fetchServices() async throws -> [GootifService] {
        let req = request(path: "/api/services")
        let data = try await perform(req)
        return try decoder.decode([GootifService].self, from: data)
    }

    static func ping(apiKey: String) async throws {
        var components = URLComponents(string: baseURL + "/api/services")!
        components.queryItems = [.init(name: "limit", value: "1")]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        req.timeoutInterval = 10
        _ = try await perform(req)
    }
}
