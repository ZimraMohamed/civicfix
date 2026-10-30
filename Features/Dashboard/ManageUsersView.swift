import SwiftUI


struct ManageUsersView: View {
    @State private var vm = ManageUsersViewModel()
    @State private var showingAdd = false

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            content
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Manage users")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $vm.search, prompt: "Search name or email")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
                .accessibilityLabel("Add user")
            }
        }
        .task { await vm.observe() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { AddUserView() }
                .presentationDetents([.large])
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { vm.errorMessage != nil },
                                    set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    @ViewBuilder private var content: some View {
        if !vm.hasLoaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.users.isEmpty {
            ContentUnavailableView(
                "No users yet",
                systemImage: "person.2",
                description: Text("Tap + to add the first account.")
            )
        } else if vm.visibleUsers.isEmpty {
            ContentUnavailableView(
                "No matches",
                systemImage: "magnifyingglass",
                description: Text("Try a different search.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.visibleUsers) { user in
                        NavigationLink {
                            UserDetailView(user: user, vm: vm)
                        } label: {
                            UserRow(user: user)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, 16)
            }
        }
    }
}



private struct UserRow: View {
    let user: UserAccount

    private var roleColor: Color {
        if user.isAdmin { return AppColors.primary }
        if user.isOfficer { return .orange }
        return AppColors.textSecondary
    }

    var body: some View {
        HStack(spacing: 12) {
            Avatar(initials: user.initials, dimmed: user.disabled)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.displayName.isEmpty ? "Unknown" : user.displayName)
                        .font(AppFonts.input)
                        .foregroundStyle(user.disabled ? AppColors.textSecondary : AppColors.textPrimary)
                        .strikethrough(user.disabled)
                    if user.disabled {
                        Text("Disabled")
                            .font(AppFonts.error)
                            .foregroundStyle(AppColors.error)
                    }
                }
                Text(user.email)
                    .font(AppFonts.error)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                Text(user.rolesText)
                    .font(AppFonts.error)
                    .foregroundStyle(roleColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.placeholder)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .contentShape(Rectangle())
    }
}

private struct Avatar: View {
    let initials: String
    var dimmed: Bool = false
    var body: some View {
        Text(initials)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Circle().fill(dimmed ? AppColors.placeholder : AppColors.primary))
    }
}

#Preview {
    NavigationStack { ManageUsersView() }
        .environment(SessionStore.preview())
}
