//
//  StaffView.swift
//  Invo Billing
//
//  Who works in the shop, and what each of them can reach.
//

import SwiftUI

struct StaffView: View {
    @StateObject private var vm = StaffViewModel()
    @State private var showAdd = false
    @State private var removing: StaffMember?

    var body: some View {
        ZStack {
            Color.sBackground.ignoresSafeArea()

            if vm.isLoading && vm.members.isEmpty {
                ProgressView().tint(.sAccent)
            } else {
                ScrollView {
                    // A plain stack: this list is a handful of people, and a lazy one
                    // here built its rows without ever laying them out.
                    VStack(alignment: .leading, spacing: 10) {
                        if vm.staffCount == 0 {
                            emptyState
                        }

                        ForEach(vm.members) { member in
                            memberCard(member)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .refreshable { await vm.load() }
            }
        }
        .navigationTitle("Staff")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showAdd) {
            NavigationStack { AddStaffSheet(vm: vm) }
        }
        .alert("Staff", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Something went wrong")
        }
        .confirmationDialog(
            removing.map { "Remove \($0.displayName)?" } ?? "",
            isPresented: Binding(
                get: { removing != nil },
                set: { if !$0 { removing = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let member = removing {
                    Task { await vm.remove(member) }
                }
                removing = nil
            }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: {
            // Said plainly, because this is the fear that stops somebody tapping it:
            // nothing they billed is going anywhere.
            Text("They won't be able to sign in to this shop. Everything they billed stays.")
        }
    }

    private func memberCard(_ member: StaffMember) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.scaled(14, weight: .medium))
                        .foregroundColor(.sForeground)
                    // Only when it adds something. An owner backfilled from an
                    // existing account has no name on their row, and printing the
                    // login twice reads like a mistake.
                    if member.displayName != member.email {
                        Text(member.email)
                            .font(.scaled(12))
                            .foregroundColor(.sMutedFG)
                    }
                }
                Spacer()
                rolePill(member)
            }

            Text(member.memberRole.explanation)
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
                .fixedSize(horizontal: false, vertical: true)

            if !member.isOwner {
                HStack(spacing: 16) {
                    // The role that isn't theirs, offered as the thing to do — a
                    // picker for two options is a menu nobody needs.
                    let other: MemberRole = member.memberRole == .manager ? .staff : .manager
                    Button("Make \(other.label.lowercased())") {
                        Task { await vm.changeRole(member, to: other) }
                    }
                    .font(.scaled(13, weight: .medium))
                    .foregroundColor(.sAccent)

                    Button("Remove") { removing = member }
                        .font(.scaled(13, weight: .medium))
                        .foregroundColor(.sDestructive)

                    Spacer()
                }
                .disabled(vm.isWorking)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sBorder, lineWidth: 0.5))
        .cornerRadius(14)
    }

    private func rolePill(_ member: StaffMember) -> some View {
        let colour: Color = member.isOwner
            ? Color(red: 0.086, green: 0.639, blue: 0.341)
            : (member.memberRole == .manager ? .sAccent : .sMutedFG)
        return Text(member.memberRole.label)
            .font(.scaled(11, weight: .medium))
            .foregroundColor(colour)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colour.opacity(0.12))
            .cornerRadius(6)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2")
                .font(.scaled(28))
                .foregroundColor(.sMutedFG)
            Text("Only you, so far")
                .font(.scaled(15, weight: .medium))
                .foregroundColor(.sForeground)
            Text("Give the people at your counter their own login. They bill customers and take payments without seeing what stock costs or what the shop earned.")
                .font(.scaled(12))
                .foregroundColor(.sMutedFG)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Button("Add someone") { showAdd = true }
                .font(.scaled(14, weight: .medium))
                .foregroundColor(.sAccent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Adding somebody

struct AddStaffSheet: View {
    @ObservedObject var vm: StaffViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var role: MemberRole = .staff

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@")
            && password.count >= 8
            && !vm.isWorking
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("They sign in with this email. If they already have an Invo account, they keep their own password.")
            }

            Section {
                SecureField("Password", text: $password)
                    // Deliberately not .newPassword. That offers to generate one and
                    // save it to this phone's keychain — but this password is not the
                    // owner's, it belongs to the person they are about to hand it to,
                    // and it would be filed under the owner's own account.
                    .textContentType(.none)
            } footer: {
                if password.isEmpty {
                    Text("At least 8 characters. Tell it to them — they can change it later.")
                } else if password.count < 8 {
                    Text("At least 8 characters.")
                        .foregroundColor(.sDestructive)
                }
            }

            Section {
                // Only the two that can be given out. The owner is the person whose
                // business it is, and that is not something handed over in a picker.
                Picker("Role", selection: $role) {
                    ForEach([MemberRole.staff, MemberRole.manager]) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(role.explanation)
                    .font(.scaled(12))
                    .foregroundColor(.sMutedFG)
            } header: {
                Text("What they can do")
            }
        }
        .navigationTitle("Add someone")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    Task {
                        let added = await vm.add(
                            name: name.trimmingCharacters(in: .whitespaces),
                            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                            password: password,
                            role: role
                        )
                        if added { dismiss() }
                    }
                }
                .disabled(!canSave)
            }
        }
    }
}
