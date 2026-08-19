import Foundation

final class CreditNoteService {
    
    static let shared = CreditNoteService()
    private let baseURL = AppEnvironment.baseURL
    
    // MARK: - Get All Credit Notes
    func fetchAll() async throws -> [CreditNoteModel] {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            throw URLError(.badURL)
        }
        let url = URL(string: "\(baseURL)/credit-notes?company_id=\(companyId)")!
        print(url)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        // Debug
        print("📡 Credit notes raw:", String(data: data, encoding: .utf8) ?? "")
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // ✅ Decode directly as array — no wrapper
        if let decoded = try? JSONDecoder().decode([CreditNoteModel].self, from: data) {
            return decoded
        }
        
        // Fallback — empty array
        return []
    }
    
    // MARK: - Get Credit Note By ID
    func fetchByID(id: Int) async throws -> CreditNoteDetailModel {
        guard let companyId = SessionManager.shared.selectedCompanyId else {
            throw URLError(.badURL)
        }
        let url = URL(string: "\(baseURL)/credit-notes/\(id)?company_id=\(companyId)")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(CreditNoteDetailModel.self, from: data)
    }
    
    // MARK: - Create Credit Note
    func create(dto: CreateCreditNoteRequestDTO) async throws {
        let url = URL(string: "\(baseURL)/credit-notes")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainManager.shared.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        req.httpBody = try JSONEncoder().encode(dto)
        
        let (_, response) = try await URLSession.shared.data(for: req)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
    }
}
