import SwiftUI

enum AppPalette {
    static let canvas = Color(red: 0.925, green: 0.922, blue: 0.902)
    static let paper = Color(red: 0.965, green: 0.965, blue: 0.953)
    static let soft = Color(red: 0.933, green: 0.933, blue: 0.918)
    static let surface = Color.white
    static let ink = Color(red: 0.125, green: 0.125, blue: 0.114)
    static let muted = Color(red: 0.455, green: 0.455, blue: 0.431)
    static let line = Color(red: 0.870, green: 0.870, blue: 0.847)
    static let accent = Color(red: 0.384, green: 0.463, blue: 0.416)
    static let accentSoft = Color(red: 0.875, green: 0.910, blue: 0.882)
    static let blue = Color(red: 0.443, green: 0.525, blue: 0.612)
    static let blueSoft = Color(red: 0.886, green: 0.910, blue: 0.933)
    static let sun = Color(red: 0.725, green: 0.608, blue: 0.271)
    static let sunSoft = Color(red: 0.945, green: 0.902, blue: 0.749)
    static let warning = Color(red: 0.608, green: 0.420, blue: 0.373)
    static let warningSoft = Color(red: 0.918, green: 0.875, blue: 0.863)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppPalette.surface)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppPalette.ink.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppPalette.ink)
            .frame(height: 38)
            .padding(.horizontal, 14)
            .background(AppPalette.surface.opacity(configuration.isPressed ? 0.6 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppPalette.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppPalette.ink)
            .frame(width: 34, height: 34)
            .background(AppPalette.surface.opacity(configuration.isPressed ? 0.62 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppPalette.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ColorReuseWarning: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(red: 0.518, green: 0.350, blue: 0.118))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.976, green: 0.923, blue: 0.790))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 0.875, green: 0.710, blue: 0.420), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
