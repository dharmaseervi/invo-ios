import SwiftUI

struct InvoiceDetailsSection: View {
    @Binding var invoiceDate: Date
    @Binding var dueDate: Date
    
    var daysUntilDue: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: invoiceDate, to: dueDate)
        return components.day ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DATES")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(1)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 16)
            
            VStack(spacing: 0) {
                // Invoice Date
                DateFieldZara(
                    label: "Invoice Date",
                    subtitle: "When the invoice was issued",
                    date: $invoiceDate
                )
                
                Divider()
                    .frame(height: 1)
                    .background(Color.black.opacity(0.08))
                    .padding(.horizontal, 24)
                
                // Due Date
                DateFieldZara(
                    label: "Due Date",
                    subtitle: "Payment deadline",
                    date: $dueDate
                )
                
                // Days Until Due Badge
                if daysUntilDue > 0 {
                    Divider()
                        .frame(height: 1)
                        .background(Color.black.opacity(0.08))
                        .padding(.horizontal, 24)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass.end")
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(.black.opacity(0.4))
                        
                        Text("Payment due in \(daysUntilDue) days")
                            .font(.system(size: 11, weight: .light, design: .default))
                            .foregroundColor(.black.opacity(0.6))
                            .tracking(0.2)
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Date Field Component (Zara Style)
struct DateFieldZara: View {
    let label: String
    let subtitle: String
    @Binding var date: Date
    
    var formattedDisplayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundColor(.gray)
                    .tracking(0.3)
                
                Text(subtitle)
                    .font(.system(size: 9, weight: .light, design: .default))
                    .foregroundColor(.gray.opacity(0.6))
                    .tracking(0.2)
            }
            .padding(.horizontal, 0)
            .padding(.top, 14)
            .padding(.bottom, 8)
            
            HStack(spacing: 12) {
                DatePicker(
                    "",
                    selection: $date,
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(.black)
                
                Spacer()
                
                // Date Display
                VStack(alignment: .trailing, spacing: 3) {
                    Text(formattedDisplayDate)
                        .font(.system(size: 12, weight: .light, design: .default))
                        .foregroundColor(.black)
                    
                    Text(dayOfWeek)
                        .font(.system(size: 10, weight: .light, design: .default))
                        .foregroundColor(.gray)
                        .tracking(0.2)
                }
            }
            .padding(.horizontal, 0)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Alternative Date Picker (Compact Style)
struct DateFieldZaraCompact: View {
    let label: String
    let subtitle: String
    @Binding var date: Date
    @State private var showPicker = false
    
    var formattedDisplayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundColor(.gray)
                    .tracking(0.3)
                
                Text(subtitle)
                    .font(.system(size: 9, weight: .light, design: .default))
                    .foregroundColor(.gray.opacity(0.6))
                    .tracking(0.2)
            }
            .padding(.horizontal, 0)
            .padding(.top, 14)
            .padding(.bottom, 8)
            
            Button(action: { showPicker.toggle() }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedDisplayDate)
                            .font(.system(size: 12, weight: .light, design: .default))
                            .foregroundColor(.black)
                        
                        Text(dayOfWeek)
                            .font(.system(size: 10, weight: .light, design: .default))
                            .foregroundColor(.gray)
                            .tracking(0.2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.black.opacity(0.4))
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 10)
            }
            
            if showPicker {
                DatePicker(
                    "",
                    selection: $date,
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(.black)
                .datePickerStyle(.graphical)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Legacy Support Components
struct DatePickerCard: View {
    let label: String
    @Binding var date: Date
    let icon: String
    let color: Color
    let subtitle: String
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                    
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(0.7)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .tint(color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedDate)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(dayOfWeek)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color.opacity(0.08))
                .cornerRadius(8)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
    }
}

struct DatePickerCardAdvanced: View {
    let label: String
    @Binding var date: Date
    let icon: String
    let color: Color
    let subtitle: String
    @State private var showPicker = false
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                    
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(0.7)
            }
            
            Button(action: { showPicker.toggle() }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedDate)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(dayOfWeek)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                .padding(12)
                .background(color.opacity(0.08))
                .cornerRadius(10)
            }
            
            if showPicker {
                VStack {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .tint(color)
                        .datePickerStyle(.graphical)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
}
