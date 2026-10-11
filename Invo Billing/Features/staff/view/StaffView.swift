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
        Group {
            if vm.isLoading && vm.members.isEmpty {
                ProgressView()
                    .tint(.sAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if vm.staffCount == 0 {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    Section {
                        ForEach(vm.members) { member in
                            memberRow(member)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 12))
                                .listRowSeparator(.hidden, edges: member.id == vm.members.first?.id ? .top : [])
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach([MemberRole.manager, MemberRole.staff]) { role in
                                Text("**\(role.label):** \(role.explanation)")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 16, for: .scrollContent)
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

    private func memberRow(_ member: StaffMember) -> some View {
        HStack(spacing: 12) {
            MinimalAvatarView(name: member.displayName)

            VStack(alignment: .leading, spacing: 3) {
                Text(member.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                // Only when it adds something. An owner backfilled from an existing
                // account has no name on their row, and printing the login twice
                // reads like a mistake.
                if member.displayName != member.email {
                    Text(member.email)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }

            Spacer(minLength: 8)

            rolePill(member)

            if member.isOwner {
                Color.clear.frame(width: 32, height: 32)
            } else {
                // The role that isn't theirs, offered as the thing to do — a picker
                // for two options is a menu nobody needs.
                let other: MemberRole = member.memberRole == .manager ? .staff : .manager
                Menu {
                    Button {
                        Task { await vm.changeRole(member, to: other) }
                    } label: {
                        Label("Make \(other.label.lowercased())", systemImage: "person.badge.key")
                    }
                    Button(role: .destructive) { removing = member } label: {
                        Label("Remove", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(vm.isWorking)
                .accessibilityLabel("Actions for \(member.displayName)")
            }
        }
        .swipeActions(edge: .trailing) {
            if !member.isOwner {
                Button("Remove", role: .destructive) { removing = member }
            }
        }
    }

    private func rolePill(_ member: StaffMember) -> some View {
        let colour: Color = member.isOwner
            ? .sSuccess
            : (member.memberRole == .manager ? .sAccent : .sMutedFG)
        return Text(member.memberRole.label)
            .font(.caption.weight(.medium))
            .foregroundColor(colour)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colour.opacity(0.12))
            .cornerRadius(6)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Only you, so far", systemImage: "person.2")
        } description: {
            Text("Give the people at your counter their own login. They bill customers and take payments without seeing what stock costs or what the shop earned.")
        } actions: {
            Button("Add someone") { showAdd = true }
                .buttonStyle(.borderedProminent)
                .tint(.sAccent)
        }
        .padding(.vertical, 16)
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
                    .font(.footnote)
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
