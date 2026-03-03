import SwiftUI

struct VendorSheet: View {
    @Binding var vendors: [VendorContact]
    let theme: AppTheme
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var showAddForm = false
    @State private var newVendorName = ""
    @State private var newVendorEmail = ""
    @State private var newVendorPhone = ""
    @State private var newVendorNotes = ""
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showAddForm {
                    addForm
                } else {
                    vendorList
                }
            }
            .background(theme.bgPrimary)
            .navigationTitle("Vendors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddForm.toggle()
                    } label: {
                        Image(systemName: showAddForm ? "xmark" : "plus")
                    }
                }
            }
        }
    }

    private var vendorList: some View {
        Group {
            if vendors.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundColor(theme.textTertiary)
                    Text("No vendors yet")
                        .font(AppTypography.body)
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vendors) { vendor in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vendor.vendor_name)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(theme.textPrimary)

                        Text(vendor.email)
                            .font(AppTypography.caption)
                            .foregroundColor(theme.textSecondary)

                        if let phone = vendor.phone, !phone.isEmpty {
                            Text(phone)
                                .font(AppTypography.caption)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
    }

    private var addForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Add Vendor")
                    .font(AppTypography.headline)
                    .foregroundColor(theme.textPrimary)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Vendor Name")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)
                    TextField("Name", text: $newVendorName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Email")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)
                    TextField("email@vendor.com", text: $newVendorEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Phone (optional)")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)
                    TextField("Phone number", text: $newVendorPhone)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.telephoneNumber)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Notes (optional)")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)
                    TextField("Notes", text: $newVendorNotes)
                        .textFieldStyle(.roundedBorder)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(theme.error)
                }

                Button {
                    Task { await addVendor() }
                } label: {
                    HStack {
                        if isAdding {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Add Vendor")
                                .font(AppTypography.bodyMedium)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.textLink)
                    .cornerRadius(AppRadius.sm)
                }
                .disabled(newVendorName.isEmpty || newVendorEmail.isEmpty || isAdding)
                .opacity(newVendorName.isEmpty || newVendorEmail.isEmpty ? 0.5 : 1)
            }
            .padding(AppSpacing.lg)
        }
    }

    private func addVendor() async {
        guard let token = authService.token else { return }
        isAdding = true
        errorMessage = nil

        do {
            let vendor = try await APIService.shared.createVendor(
                token: token,
                vendorName: newVendorName,
                email: newVendorEmail,
                phone: newVendorPhone.isEmpty ? nil : newVendorPhone,
                notes: newVendorNotes.isEmpty ? nil : newVendorNotes
            )
            vendors.append(vendor)
            showAddForm = false
            newVendorName = ""
            newVendorEmail = ""
            newVendorPhone = ""
            newVendorNotes = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isAdding = false
    }
}
