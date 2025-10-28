import SwiftUI

struct AddCustomModelCardView: View {
    @ObservedObject var customModelManager: CustomModelManager
    var onModelAdded: () -> Void
    var editingModel: CustomCloudModel? = nil
    
    @State private var isExpanded = false
    @State private var displayName = ""
    @State private var apiEndpoint = ""
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var isMultilingual = true
    
    @State private var validationErrors: [String] = []
    @State private var showingAlert = false
    @State private var isSaving = false
    @State private var isTesting = false
    @State private var testResult: String? = nil
    @State private var testSuccess: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Simple Add Model Button
            if !isExpanded {
                Button(action: {
                    withAnimation(.interpolatingSpring(stiffness: 170, damping: 20)) {
                        isExpanded = true
                        // Pre-fill values - either from editing model or defaults
                        if let editing = editingModel {
                            displayName = editing.displayName
                            apiEndpoint = editing.apiEndpoint
                            apiKey = editing.apiKey
                            modelName = editing.modelName
                            isMultilingual = editing.isMultilingualModel
                        } else {
                            // Pre-fill some default values when adding new
                            if apiEndpoint.isEmpty {
                                apiEndpoint = "https://api.example.com/v1/audio/transcriptions"
                            }
                            if modelName.isEmpty {
                                modelName = "large-v3-turbo"
                            }
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                        Text(editingModel != nil ? "Edit Model" : "Add Model")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
            }
            
            // Expandable Form Section
            if isExpanded {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Text(editingModel != nil ? "Edit Custom Model" : "Add Custom Model")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 170, damping: 20)) {
                                isExpanded = false
                                clearForm()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Disclaimer
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Only OpenAI-compatible transcription APIs are supported")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Form fields
                    VStack(alignment: .leading, spacing: 16) {
                        FormField(title: "Display Name", text: $displayName, placeholder: "My Custom Model")
                        FormField(title: "API Endpoint", text: $apiEndpoint, placeholder: "https://api.example.com/v1/audio/transcriptions")
                        FormField(title: "API Key", text: $apiKey, placeholder: "your-api-key", isSecure: true)
                        FormField(title: "Model Name", text: $modelName, placeholder: "whisper-1")
                        
                        Toggle("Multilingual Model", isOn: $isMultilingual)
                        
                        // Test Connection Section
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                testConnection()
                            }) {
                                HStack(spacing: 6) {
                                    if isTesting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .font(.system(size: 14))
                                    }
                                    Text("Test Connection")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isFormValid || isTesting)
                            
                            if let result = testResult {
                                HStack(spacing: 8) {
                                    Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(testSuccess ? .green : .red)
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(testSuccess ? .green : .red)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill((testSuccess ? Color.green : Color.red).opacity(0.1))
                                )
                            }
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 170, damping: 20)) {
                                isExpanded = false
                                clearForm()
                            }
                        }) {
                            Text("Cancel")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            addModel()
                        }) {
                            HStack(spacing: 6) {
                                if isSaving {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: editingModel != nil ? "checkmark.circle.fill" : "plus.circle.fill")
                                        .font(.system(size: 14))
                                }
                                Text(editingModel != nil ? "Update Model" : "Add Model")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isFormValid ? Color(.controlAccentColor) : Color.secondary)
                                    .shadow(color: (isFormValid ? Color(.controlAccentColor) : Color.secondary).opacity(0.2), radius: 2, x: 0, y: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!isFormValid || isSaving)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.windowBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separatorColor), lineWidth: 1)
                        )
                )
            }
        }
        .alert("Validation Errors", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(validationErrors.joined(separator: "\n"))
        }
        .onChange(of: editingModel) { oldValue, newValue in
            if newValue != nil {
                withAnimation(.interpolatingSpring(stiffness: 170, damping: 20)) {
                    isExpanded = true
                    // Pre-fill values from editing model
                    if let editing = newValue {
                        displayName = editing.displayName
                        apiEndpoint = editing.apiEndpoint
                        apiKey = editing.apiKey
                        modelName = editing.modelName
                        isMultilingual = editing.isMultilingualModel
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func clearForm() {
        displayName = ""
        apiEndpoint = ""
        apiKey = ""
        modelName = ""
        isMultilingual = true
        testResult = nil
        testSuccess = false
    }
    
    private func testConnection() {
        testResult = nil
        isTesting = true
        
        Task {
            do {
                let trimmedEndpoint = apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Create a test model
                let testModel = CustomCloudModel(
                    name: "test",
                    displayName: "Test",
                    description: "Test",
                    apiEndpoint: trimmedEndpoint,
                    apiKey: trimmedKey,
                    modelName: trimmedModelName,
                    isMultilingual: isMultilingual
                )
                
                // Test the endpoint
                let result = await customModelManager.testEndpoint(model: testModel)
                
                await MainActor.run {
                    isTesting = false
                    testSuccess = result.success
                    testResult = result.message
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testSuccess = false
                    testResult = "Unexpected error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func addModel() {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiEndpoint = apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Generate a name from display name (lowercase, no spaces)
        let generatedName = trimmedDisplayName.lowercased().replacingOccurrences(of: " ", with: "-")
        
        validationErrors = customModelManager.validateModel(
            name: generatedName,
            displayName: trimmedDisplayName,
            apiEndpoint: trimmedApiEndpoint,
            apiKey: trimmedApiKey,
            modelName: trimmedModelName,
            excludingId: editingModel?.id
        )
        
        if !validationErrors.isEmpty {
            showingAlert = true
            return
        }
        
        isSaving = true
        
        // Simulate a brief save operation for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let editing = editingModel {
                // Update existing model
                let updatedModel = CustomCloudModel(
                    id: editing.id,
                    name: generatedName,
                    displayName: trimmedDisplayName,
                    description: "Custom transcription model",
                    apiEndpoint: trimmedApiEndpoint,
                    apiKey: trimmedApiKey,
                    modelName: trimmedModelName,
                    isMultilingual: isMultilingual
                )
                customModelManager.updateCustomModel(updatedModel)
            } else {
                // Add new model
                let customModel = CustomCloudModel(
                    name: generatedName,
                    displayName: trimmedDisplayName,
                    description: "Custom transcription model",
                    apiEndpoint: trimmedApiEndpoint,
                    apiKey: trimmedApiKey,
                    modelName: trimmedModelName,
                    isMultilingual: isMultilingual
                )
                customModelManager.addCustomModel(customModel)
            }
            
            onModelAdded()
            
            // Reset form and collapse
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 20)) {
                isExpanded = false
                clearForm()
                isSaving = false
            }
        }
    }
}

struct FormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
} 