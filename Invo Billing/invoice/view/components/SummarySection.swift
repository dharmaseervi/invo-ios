import SwiftUI

struct SummarySection: View {
    let subtotal: Double
    let tax: Double
    let total: Double
    
    var taxPercentage: Double {
        subtotal > 0 ? (tax / subtotal) * 100 : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SUMMARY")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(1)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 16)
            
            VStack(spacing: 0) {
                // Subtotal Row
                SummaryRowZara(
                    label: "Subtotal",
                    value: subtotal,
                    isTotal: false
                )
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))
                    .padding(.horizontal, 24)
                
                // Tax Row with percentage
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tax")
                            .font(.system(size: 12, weight: .light, design: .default))
                            .foregroundColor(.black)
                        
                        Text("(\(String(format: "%.1f", taxPercentage))%)")
                            .font(.system(size: 10, weight: .light, design: .default))
                            .foregroundColor(.gray)
                            .tracking(0.2)
                    }
                    
                    Spacer()
                    
                    Text("₹\(String(format: "%.2f", tax))")
                        .font(.system(size: 12, weight: .light, design: .default))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))
                    .padding(.horizontal, 24)
                
                // Total Row - Highlighted
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Amount")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundColor(.black)
                            
                            Text("Amount due by invoice date")
                                .font(.system(size: 10, weight: .light, design: .default))
                                .foregroundColor(.gray)
                                .tracking(0.2)
                        }
                        
                        Spacer()
                        
                        Text("₹\(String(format: "%.2f", total))")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
            }
         
        }
    }
}

// MARK: - Summary Row Component (Zara Style)
struct SummaryRowZara: View {
    let label: String
    let value: Double
    var isTotal: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: isTotal ? 13 : 12, weight: isTotal ? .semibold : .light, design: .default))
                .foregroundColor(.black)
                .tracking(isTotal ? 0 : 0.2)
            
            Spacer()
            
            Text("₹\(String(format: "%.2f", value))")
                .font(.system(size: isTotal ? 14 : 12, weight: isTotal ? .semibold : .light, design: .default))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

// MARK: - Legacy Summary Row Component (for compatibility)
struct SummaryRows: View {
    let label: String
    let value: Double
    let icon: String
    let color: Color
    let isTotal: Bool
    var subtitle: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24)
            
            // Label and Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: isTotal ? 15 : 13, weight: isTotal ? .bold : .semibold))
                    .foregroundColor(.primary)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 0) {
                Text("₹\(String(format: "%.2f", value))")
                    .font(.system(size: isTotal ? 18 : 14, weight: isTotal ? .bold : .semibold))
                    .foregroundColor(isTotal ? .blue : .primary)
                
                if isTotal {
                    Text("Due")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .padding(isTotal ? 14 : 0)
        .background(isTotal ? Color.blue.opacity(0.08) : Color.clear)
        .cornerRadius(isTotal ? 10 : 0)
    }
}
