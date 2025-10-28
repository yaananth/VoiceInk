import Foundation
import os

class CustomModelManager: ObservableObject {
    static let shared = CustomModelManager()
    
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "CustomModelManager")
    private let userDefaults = UserDefaults.standard
    private let customModelsKey = "customCloudModels"
    
    @Published var customModels: [CustomCloudModel] = []
    
    private init() {
        loadCustomModels()
    }
    
    // MARK: - CRUD Operations
    
    func addCustomModel(_ model: CustomCloudModel) {
        customModels.append(model)
        saveCustomModels()
        logger.info("Added custom model: \(model.displayName)")
    }
    
    func removeCustomModel(withId id: UUID) {
        customModels.removeAll { $0.id == id }
        saveCustomModels()
        logger.info("Removed custom model with ID: \(id)")
    }
    
    func updateCustomModel(_ updatedModel: CustomCloudModel) {
        if let index = customModels.firstIndex(where: { $0.id == updatedModel.id }) {
            customModels[index] = updatedModel
            saveCustomModels()
            logger.info("Updated custom model: \(updatedModel.displayName)")
        }
    }
    
    // MARK: - Persistence
    
    private func loadCustomModels() {
        guard let data = userDefaults.data(forKey: customModelsKey) else {
            logger.info("No custom models found in UserDefaults")
            return
        }
        
        do {
            customModels = try JSONDecoder().decode([CustomCloudModel].self, from: data)
        } catch {
            logger.error("Failed to decode custom models: \(error.localizedDescription)")
            customModels = []
        }
    }
    
    func saveCustomModels() {
        do {
            let data = try JSONEncoder().encode(customModels)
            userDefaults.set(data, forKey: customModelsKey)
        } catch {
            logger.error("Failed to encode custom models: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Validation
    
    func validateModel(name: String, displayName: String, apiEndpoint: String, apiKey: String, modelName: String) -> [String] {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Name cannot be empty")
        }
        
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Display name cannot be empty")
        }
        
        if apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("API endpoint cannot be empty")
        } else if !isValidURL(apiEndpoint) {
            errors.append("API endpoint must be a valid URL")
        }
        
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("API key cannot be empty")
        }
        
        if modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Model name cannot be empty")
        }
        
        // Check for duplicate names
        if customModels.contains(where: { $0.name == name }) {
            errors.append("A model with this name already exists")
        }
        
        return errors
    }
    
    func validateModel(name: String, displayName: String, apiEndpoint: String, apiKey: String, modelName: String, excludingId: UUID? = nil) -> [String] {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Name cannot be empty")
        }
        
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Display name cannot be empty")
        }
        
        if apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("API endpoint cannot be empty")
        } else if !isValidURL(apiEndpoint) {
            errors.append("API endpoint must be a valid URL")
        }
        
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("API key cannot be empty")
        }
        
        if modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Model name cannot be empty")
        }
        
        // Check for duplicate names, excluding the specified ID
        if customModels.contains(where: { $0.name == name && $0.id != excludingId }) {
            errors.append("A model with this name already exists")
        }
        
        return errors
    }
    
    private func isValidURL(_ string: String) -> Bool {
        if let url = URL(string: string) {
            return url.scheme != nil && url.host != nil
        }
        return false
    }
    
    // MARK: - Testing
    
    func testEndpoint(model: CustomCloudModel) async -> (success: Bool, message: String) {
        // Create a minimal test audio file in memory (1 second of silence)
        let sampleRate = 16000
        let duration = 1.0
        let frameCount = Int(Double(sampleRate) * duration)
        
        // Create a silent WAV file in memory
        guard let testAudioData = createSilentWAVData(sampleRate: sampleRate, frameCount: frameCount) else {
            return (false, "Failed to create test audio data")
        }
        
        // Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_audio_\(UUID().uuidString).wav")
        
        do {
            try testAudioData.write(to: tempURL)
            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }
            
            // Create service and test
            let service = OpenAICompatibleTranscriptionService()
            
            do {
                let _ = try await service.transcribe(audioURL: tempURL, model: model)
                return (true, "✓ Connection successful! Endpoint is working correctly.")
            } catch let error as CloudTranscriptionError {
                return (false, formatCloudError(error))
            } catch {
                return (false, "Connection failed: \(error.localizedDescription)")
            }
        } catch {
            return (false, "Failed to write test audio file: \(error.localizedDescription)")
        }
    }
    
    private func formatCloudError(_ error: CloudTranscriptionError) -> String {
        switch error {
        case .apiRequestFailed(let statusCode, let message):
            var details = "HTTP \(statusCode)"
            if statusCode == 401 {
                details += " - Authentication failed. Check your API key."
            } else if statusCode == 403 {
                details += " - Access forbidden. Verify API key permissions."
            } else if statusCode == 404 {
                details += " - Endpoint not found. Check the API endpoint URL."
            } else if statusCode == 422 {
                details += " - Invalid request. Check model name and parameters."
            } else if statusCode >= 500 {
                details += " - Server error. The API service may be down."
            }
            
            if !message.isEmpty {
                details += "\nServer response: \(message)"
            }
            return details
            
        case .networkError(let wrappedError):
            if let urlError = wrappedError as? URLError {
                if urlError.code == .cannotFindHost {
                    return "Cannot find host. Check the API endpoint URL."
                } else if urlError.code == .notConnectedToInternet {
                    return "No internet connection."
                } else if urlError.code == .timedOut {
                    return "Request timed out. The server may be slow or unreachable."
                } else if urlError.code == .secureConnectionFailed {
                    return "SSL/TLS connection failed. Check if HTTPS is required."
                } else {
                    return "Network error: \(urlError.localizedDescription)"
                }
            } else {
                return "Network error: \(wrappedError.localizedDescription)"
            }
            
        case .audioFileNotFound:
            return "Audio file not found (internal error)"
            
        case .noTranscriptionReturned:
            return "No transcription in response. The endpoint may not be OpenAI-compatible."
            
        case .rateLimitExceeded:
            return "Rate limit exceeded. Try again later."
            
        case .invalidAPIKey:
            return "Invalid API key. Check your credentials."
            
        case .requestTooLarge:
            return "Request too large."
            
        case .modelNotAvailable:
            return "Model not available. Check the model name."
            
        case .unsupportedProvider:
            return "Unsupported provider."
            
        case .missingAPIKey:
            return "Missing API key."
            
        case .dataEncodingError:
            return "Data encoding error."
        }
    }
    
    private func createSilentWAVData(sampleRate: Int, frameCount: Int) -> Data? {
        var data = Data()
        
        // WAV header
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate * Int(numChannels) * Int(bitsPerSample) / 8)
        let blockAlign = UInt16(numChannels * bitsPerSample / 8)
        let dataSize = UInt32(frameCount * Int(blockAlign))
        let fileSize = 36 + dataSize
        
        // RIFF header
        data.append("RIFF".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        data.append("fmt ".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // audio format (PCM)
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        
        // data chunk
        data.append("data".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        
        // Silent audio data (all zeros)
        data.append(Data(count: Int(dataSize)))
        
        return data
    }
} 
