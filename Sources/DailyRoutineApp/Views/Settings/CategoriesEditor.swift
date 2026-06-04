import SwiftUI

struct CategoriesEditor: View {
    @EnvironmentObject var store: AppStore
    @State private var newCategory = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Add new category
            VStack(alignment: .leading, spacing: 10) {
                Text("NEW CATEGORY")
                    .eyebrow()

                HStack(spacing: 10) {
                    TextField("Category name", text: $newCategory)
                        .font(AppFonts.mono(13))
                        .appField()
                        .onSubmit { addCategory() }

                    Button("Add") { addCategory() }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Divider()

            // Existing categories
            if store.categories.isEmpty {
                Text("No categories yet.")
                    .font(AppFonts.mono(12))
                    .foregroundColor(AppColors.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 1) {
                    ForEach(store.categories, id: \.self) { cat in
                        HStack {
                            Text(cat)
                                .font(AppFonts.mono(13))
                                .foregroundColor(AppColors.ink)
                            Spacer()
                            Button {
                                store.deleteCategory(cat)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.high)
                            }
                            .buttonStyle(.plain)
                            .help("Delete category")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.surface)
                    }
                }
                .background(AppColors.borderWeak)
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(AppColors.borderMid))
            }

            Text("Deleting a category does not remove it from existing tasks.")
                .font(AppFonts.mono(10))
                .foregroundColor(AppColors.inkFaint)
        }
    }

    private func addCategory() {
        store.addCategory(newCategory)
        newCategory = ""
    }
}
