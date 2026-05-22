import SwiftUI

enum AppPalette {
    static let paper = Color(red: 0.965, green: 0.965, blue: 0.953)
    static let surface = Color.white
    static let ink = Color(red: 0.125, green: 0.125, blue: 0.114)
    static let muted = Color(red: 0.455, green: 0.455, blue: 0.431)
    static let line = Color(red: 0.870, green: 0.870, blue: 0.847)
    static let accent = Color(red: 0.384, green: 0.463, blue: 0.416)
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
