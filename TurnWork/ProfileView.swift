import SwiftUI

struct ProfileView: View {
    @State private var showingShiftSchedule = false
    @AppStorage("userName") private var userName = "未设置"
    @AppStorage("userRole") private var userRole = "职员"
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            List {
                // 用户信息区域
                Section {
                    HStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(userName)
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text(userRole)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button {
                            showingEditProfile = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 功能列表
                Section {
                    NavigationLink(destination: ShiftScheduleView()) {
                        ProfileRowView(
                            icon: "clock.badge.checkmark.fill",
                            iconColor: .purple,
                            title: "排班设置"
                        )
                    }
                    
                    NavigationLink(destination: Text("工作记录")) {
                        ProfileRowView(
                            icon: "calendar.badge.clock",
                            iconColor: .blue,
                            title: "工作记录"
                        )
                    }
                    
                    Button {
                        exportData()
                    } label: {
                        ProfileRowView(
                            icon: "square.and.arrow.up.fill",
                            iconColor: .green,
                            title: "导出统计",
                            showChevron: true
                        )
                    }
                }
                
                // 系统设置
                Section {
                    NavigationLink(destination: Text("设置页面")) {
                        ProfileRowView(
                            icon: "gearshape.fill",
                            iconColor: .gray,
                            title: "设置"
                        )
                    }
                    
                    NavigationLink(destination: Text("关于页面")) {
                        ProfileRowView(
                            icon: "info.circle.fill",
                            iconColor: .blue,
                            title: "关于"
                        )
                    }
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(userName: $userName, userRole: $userRole)
            }
        }
    }
    
    private func exportData() {
        // 导出数据的实现
    }
}

// 个人资料编辑视图
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var userName: String
    @Binding var userRole: String
    @State private var tempUserName: String = ""
    @State private var tempUserRole: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("姓名", text: $tempUserName)
                    TextField("职位", text: $tempUserRole)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarItems(
                leading: Button("取消") { dismiss() },
                trailing: Button("保存") {
                    userName = tempUserName
                    userRole = tempUserRole
                    dismiss()
                }
            )
            .onAppear {
                tempUserName = userName
                tempUserRole = userRole
            }
        }
    }
}

// 个人页面行视图组件
struct ProfileRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = false
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    ProfileView()
} 