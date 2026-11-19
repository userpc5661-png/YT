import SwiftUI

struct ProfilePickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.laylLayout) private var layout
    @State private var managing = false
    @State private var showingAdd = false
    @State private var pendingDelete: Profile?

    private var columns: [GridItem] {
        let minimum: CGFloat = switch layout.phoneClass {
        case .proMax, .pad: layout.avatarSize
        case .pro, .standard, .compact, .se: layout.avatarSize
        }
        return [GridItem(.adaptive(minimum: minimum), spacing: 22)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    BrandLockup(mark: 72)
                        .padding(.top, 28)

                    Text(model.language.t("من يشاهد؟", "Who's watching?"))
                        .font(.system(size: 34, weight: .medium))

                    LazyVGrid(columns: columns, spacing: 26) {
                        ForEach(model.profiles) { profile in
                            profileButton(profile)
                        }
                        addButton
                    }
                    .padding(.horizontal, 24)

                    Text(model.language.t(
                        "ملفاتك وقائمتك وتقدّم المشاهدة تُحفظ على هذا الجهاز فقط. التشغيل يحتاج إلى إنترنت.",
                        "Profiles, My List, and playback progress stay on this device. Playback needs an internet connection."
                    ))
                    .font(.footnote)
                    .foregroundStyle(LaylTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                    languageButton
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .laylScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAdd) {
                AddProfileSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert(
                model.language.t("حذف الملف؟", "Delete profile?"),
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { profile in
                Button(model.language.t("حذف", "Delete"), role: .destructive) {
                    model.deleteProfile(profile)
                    pendingDelete = nil
                }
                Button(model.language.t("إلغاء", "Cancel"), role: .cancel) {
                    pendingDelete = nil
                }
            } message: { profile in
                Text(model.language.t(
                    "ستُحذف قائمة \(profile.name) وتقدّم المشاهدة من هذا الجهاز.",
                    "\(profile.name)'s list and watch progress will be removed from this device."
                ))
            }
        }
        .environment(\.layoutDirection, model.language == .arabic ? .rightToLeft : .leftToRight)
    }

    private func profileButton(_ profile: Profile) -> some View {
        Button {
            if managing {
                pendingDelete = profile
            } else {
                model.select(profile)
            }
        } label: {
            VStack(spacing: 10) {
                ProfileAvatar(profile: profile, size: layout.avatarSize, selected: false, rounded: true)
                    .overlay(alignment: .topLeading) {
                        if managing && model.profiles.count > 1 {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(.black.opacity(0.7)))
                                .padding(4)
                        }
                    }
                Text(profile.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                if profile.isKids {
                    Text(model.language.t("أطفال", "Kids"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: profile.colorHex).opacity(0.25), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .frame(minWidth: 120, minHeight: 160)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        VStack(spacing: 10) {
            Button {
                showingAdd = true
            } label: {
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .frame(width: 112, height: 112)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title.weight(.medium))
                    }
            }
            .buttonStyle(.plain)
            Text(model.language.t("إضافة ملف", "Add profile"))
                .font(.callout)
            Button(managing ? model.language.t("تم", "Done") : model.language.t("إدارة", "Manage")) {
                managing.toggle()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(LaylTheme.muted)
        }
    }

    private var languageButton: some View {
        Button(action: model.toggleLanguage) {
            Text(model.language == .arabic ? "English" : "العربية")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct AddProfileSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color = Profile.palette[0]
    @State private var isKids = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                TextField(model.language.t("الاسم", "Name"), text: $name)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .submitLabel(.done)

                Text(model.language.t("اللون", "Color"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LaylTheme.muted)
                HStack(spacing: 12) {
                    ForEach(Profile.palette, id: \.self) { hex in
                        Button {
                            color = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if color == hex {
                                        Circle().strokeBorder(.white, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle(model.language.t("ملف أطفال", "Kids profile"), isOn: $isKids)
                    .tint(LaylTheme.red)

                Text(model.language.t(
                    "ملف الأطفال يخفي الرعب والأفلام غير العائلية.",
                    "A kids profile hides horror and titles that are not marked for family viewing."
                ))
                .font(.footnote)
                .foregroundStyle(LaylTheme.muted)

                Spacer()
            }
            .padding(20)
            .background(LaylTheme.bg)
            .navigationTitle(model.language.t("ملف جديد", "New profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.language.t("إلغاء", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.language.t("حفظ", "Save")) {
                        model.addProfile(name: name, colorHex: color, isKids: isKids)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .laylNavigationChrome()
        }
        .environment(\.layoutDirection, model.language == .arabic ? .rightToLeft : .leftToRight)
        .preferredColorScheme(.dark)
    }
}
