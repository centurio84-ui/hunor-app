import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: AppStore
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("HUNOR belépés") {
                    TextField("E-mail-cím", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Jelszó", text: $password)

                    Button {
                        Task { await store.signIn(email: email, password: password) }
                    } label: {
                        if store.isLoading { ProgressView() } else { Text("Belépés") }
                    }
                    .disabled(email.isEmpty || password.isEmpty || store.isLoading)
                }

                if let error = store.errorMessage {
                    Section("Hiba") { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("HUNOR")
        }
    }
}
