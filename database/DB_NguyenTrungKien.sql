/* =====================================================================
   CƠ SỞ DỮ LIỆU: DB_NguyenTrungKien  (SQL Server)
   Ứng dụng quản lý điện thoại trẻ em – KidGuard

   CÁCH 1 (khuyên dùng): chỉ cần chạy Web API, Entity Framework tự tạo
   database + dữ liệu mẫu (tài khoản admin/staff/phuhuynh).
   CÁCH 2: chạy script này trong SSMS để tạo bảng trước (dùng để vẽ
   Database Diagram cho báo cáo). Sau đó chạy API để sinh dữ liệu mẫu.
   ===================================================================== */

IF DB_ID(N'DB_NguyenTrungKien') IS NULL
    CREATE DATABASE DB_NguyenTrungKien;
GO
USE DB_NguyenTrungKien;
GO

/* ---------- 1. Người dùng: Admin / Staff (nhân viên) / Parent (phụ huynh) ---------- */
CREATE TABLE Users (
    Id              INT IDENTITY(1,1) CONSTRAINT PK_Users PRIMARY KEY,
    Username        NVARCHAR(50)  NOT NULL,
    Email           NVARCHAR(120) NOT NULL,
    FullName        NVARCHAR(100) NOT NULL,
    Phone           NVARCHAR(20)  NULL,
    PasswordHash    NVARCHAR(MAX) NOT NULL,           -- BCrypt
    Role            NVARCHAR(20)  NOT NULL,           -- Admin | Staff | Parent
    EmailConfirmed  BIT NOT NULL,
    IsLocked        BIT NOT NULL,
    FaceTemplate    NVARCHAR(MAX) NULL,               -- vector đặc trưng khuôn mặt (JSON)
    CreatedAt       DATETIME2 NOT NULL,
    LastLoginAt     DATETIME2 NULL
);
CREATE UNIQUE INDEX IX_Users_Username ON Users(Username);
CREATE UNIQUE INDEX IX_Users_Email    ON Users(Email);

/* ---------- 2. Hồ sơ trẻ em ---------- */
CREATE TABLE Children (
    Id                 INT IDENTITY(1,1) CONSTRAINT PK_Children PRIMARY KEY,
    ParentId           INT NOT NULL CONSTRAINT FK_Children_Users_ParentId REFERENCES Users(Id) ON DELETE CASCADE,
    Name               NVARCHAR(100) NOT NULL,
    BirthDate          DATETIME2 NULL,
    AvatarColor        NVARCHAR(20) NOT NULL,
    DailyLimitMinutes  INT NOT NULL,
    BonusMinutes       INT NOT NULL,                  -- Ví thời gian
    BedTime            NVARCHAR(5) NOT NULL,
    CreatedAt          DATETIME2 NOT NULL
);
CREATE INDEX IX_Children_ParentId ON Children(ParentId);

/* ---------- 3. Thiết bị của trẻ (ghép bằng QR) ---------- */
CREATE TABLE Devices (
    Id            INT IDENTITY(1,1) CONSTRAINT PK_Devices PRIMARY KEY,
    ChildId       INT NOT NULL CONSTRAINT FK_Devices_Children_ChildId REFERENCES Children(Id) ON DELETE CASCADE,
    DeviceName    NVARCHAR(100) NOT NULL,
    Platform      NVARCHAR(50)  NOT NULL,
    BatteryLevel  INT NULL,
    IsActive      BIT NOT NULL,
    PairedAt      DATETIME2 NOT NULL,
    LastSeenAt    DATETIME2 NULL
);
CREATE INDEX IX_Devices_ChildId ON Devices(ChildId);

/* ---------- 4. Mã ghép QR ---------- */
CREATE TABLE PairingCodes (
    Id         INT IDENTITY(1,1) CONSTRAINT PK_PairingCodes PRIMARY KEY,
    ChildId    INT NOT NULL CONSTRAINT FK_PairingCodes_Children_ChildId REFERENCES Children(Id) ON DELETE CASCADE,
    Code       NVARCHAR(64) NOT NULL,
    ExpiresAt  DATETIME2 NOT NULL,
    Used       BIT NOT NULL
);
CREATE UNIQUE INDEX IX_PairingCodes_Code ON PairingCodes(Code);
CREATE INDEX IX_PairingCodes_ChildId ON PairingCodes(ChildId);

/* ---------- 5. Lịch sử vị trí ---------- */
CREATE TABLE LocationLogs (
    Id            BIGINT IDENTITY(1,1) CONSTRAINT PK_LocationLogs PRIMARY KEY,
    ChildId       INT NOT NULL CONSTRAINT FK_LocationLogs_Children_ChildId REFERENCES Children(Id) ON DELETE CASCADE,
    Latitude      FLOAT NOT NULL,
    Longitude     FLOAT NOT NULL,
    Accuracy      FLOAT NULL,
    BatteryLevel  INT NULL,
    RecordedAt    DATETIME2 NOT NULL
);
CREATE INDEX IX_LocationLogs_ChildId_RecordedAt ON LocationLogs(ChildId, RecordedAt);

/* ---------- 6. Vùng an toàn ---------- */
CREATE TABLE SafeZones (
    Id            INT IDENTITY(1,1) CONSTRAINT PK_SafeZones PRIMARY KEY,
    ChildId       INT NOT NULL CONSTRAINT FK_SafeZones_Children_ChildId REFERENCES Children(Id) ON DELETE CASCADE,
    Name          NVARCHAR(100) NOT NULL,
    Latitude      FLOAT NOT NULL,
    Longitude     FLOAT NOT NULL,
    RadiusMeters  FLOAT NOT NULL,
    IsActive      BIT NOT NULL
);
CREATE INDEX IX_SafeZones_ChildId ON SafeZones(ChildId);

/* ---------- 7. Quy tắc ứng dụng ---------- */
CREATE TABLE AppRules (
    Id                 INT IDENTITY(1,1) CONSTRAINT PK_AppRules PRIMARY KEY,
    ChildId            INT NOT NULL CONSTRAINT FK_AppRules_Children_ChildId REFERENCES Children(Id) ON DELETE CASCADE,
    AppName            NVARCHAR(100) NOT NULL,
    Category           NVARCHAR(50)  NOT NULL,
    DailyLimitMinutes  INT NOT NULL,                  -- 0 = không giới hạn
    IsBlocked          BIT NOT NULL
);
CREATE INDEX IX_AppRules_ChildId ON AppRules(ChildId);

/* ---------- 8. Nhiệm vụ đổi thời gian (TÍNH NĂNG MỚI) ---------- */
CREATE TABLE RewardTasks (
    Id             INT IDENTITY(1,1) CONSTRAINT PK_RewardTasks PRIMARY KEY,
    ChildId        INT NOT NULL CONSTRAINT FK_RewardTasks_Children_ChildId REFERENCES Children(Id) ON DELETE CASCADE,
    Title          NVARCHAR(150) NOT NULL,
    Description    NVARCHAR(500) NULL,
    RewardMinutes  INT NOT NULL,
    DueDate        DATETIME2 NULL,
    Status         NVARCHAR(20) NOT NULL,             -- Assigned | Submitted | Approved | Rejected
    ProofImageUrl  NVARCHAR(MAX) NULL,
    ChildNote      NVARCHAR(500) NULL,
    ParentComment  NVARCHAR(500) NULL,
    CreatedAt      DATETIME2 NOT NULL,
    SubmittedAt    DATETIME2 NULL,
    ReviewedAt     DATETIME2 NULL
);
CREATE INDEX IX_RewardTasks_ChildId ON RewardTasks(ChildId);

/* ---------- 9. Giao dịch ví thời gian ---------- */
CREATE TABLE WalletTransactions (
    Id         INT IDENTITY(1,1) CONSTRAINT PK_WalletTransactions PRIMARY KEY,
    ChildId    INT NOT NULL CONSTRAINT FK_WalletTransactions_Children_ChildId REFERENCES Children(Id) ON DELETE CASCADE,
    Minutes    INT NOT NULL,
    Reason     NVARCHAR(200) NOT NULL,
    CreatedAt  DATETIME2 NOT NULL
);
CREATE INDEX IX_WalletTransactions_ChildId ON WalletTransactions(ChildId);

/* ---------- 10. Cảnh báo ---------- */
CREATE TABLE Alerts (
    Id         INT IDENTITY(1,1) CONSTRAINT PK_Alerts PRIMARY KEY,
    ChildId    INT NOT NULL CONSTRAINT FK_Alerts_Children_ChildId REFERENCES Children(Id) ON DELETE CASCADE,
    Type       NVARCHAR(30)  NOT NULL,                -- SOS | LeaveZone | LowBattery | TaskSubmitted | Info
    Message    NVARCHAR(300) NOT NULL,
    Latitude   FLOAT NULL,
    Longitude  FLOAT NULL,
    IsRead     BIT NOT NULL,
    CreatedAt  DATETIME2 NOT NULL
);
CREATE INDEX IX_Alerts_ChildId ON Alerts(ChildId);

/* ---------- 11. Yêu cầu hỗ trợ (nhân viên xử lý) ---------- */
CREATE TABLE SupportTickets (
    Id               INT IDENTITY(1,1) CONSTRAINT PK_SupportTickets PRIMARY KEY,
    ParentId         INT NOT NULL CONSTRAINT FK_SupportTickets_Users_ParentId REFERENCES Users(Id) ON DELETE CASCADE,
    AssignedStaffId  INT NULL     CONSTRAINT FK_SupportTickets_Users_AssignedStaffId REFERENCES Users(Id),
    Subject          NVARCHAR(150)  NOT NULL,
    Content          NVARCHAR(2000) NOT NULL,
    StaffReply       NVARCHAR(2000) NULL,
    Status           NVARCHAR(20) NOT NULL,           -- Open | InProgress | Resolved
    Priority         NVARCHAR(10) NOT NULL,           -- Low | Normal | High
    CreatedAt        DATETIME2 NOT NULL,
    UpdatedAt        DATETIME2 NULL
);
CREATE INDEX IX_SupportTickets_ParentId ON SupportTickets(ParentId);
CREATE INDEX IX_SupportTickets_AssignedStaffId ON SupportTickets(AssignedStaffId);

/* ---------- 12. Mã OTP qua email ---------- */
CREATE TABLE OtpCodes (
    Id         INT IDENTITY(1,1) CONSTRAINT PK_OtpCodes PRIMARY KEY,
    UserId     INT NOT NULL CONSTRAINT FK_OtpCodes_Users_UserId REFERENCES Users(Id) ON DELETE CASCADE,
    Purpose    NVARCHAR(20)  NOT NULL,                -- Register | Login | ResetPassword
    CodeHash   NVARCHAR(100) NOT NULL,                -- SHA-256, không lưu mã gốc
    ExpiresAt  DATETIME2 NOT NULL,
    Attempts   INT NOT NULL,
    Used       BIT NOT NULL,
    CreatedAt  DATETIME2 NOT NULL
);
CREATE INDEX IX_OtpCodes_UserId ON OtpCodes(UserId);
GO

PRINT N'Đã tạo xong DB_NguyenTrungKien. Chạy Web API để sinh dữ liệu mẫu.';
