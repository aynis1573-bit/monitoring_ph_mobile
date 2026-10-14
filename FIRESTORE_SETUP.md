# Checklist konfigurasi Firebase

## 1. Authentication

1. Buka Firebase Console untuk project yang sama dengan konfigurasi Flutter dan ESP32.
2. Authentication → Sign-in method → aktifkan Email/Password.
3. Authentication → Users → Add user untuk membuat akun pengelola dan maintenance.
4. Salin UID masing-masing akun.

## 2. Profil role

Buat dokumen di Firestore collection `users`, dengan Document ID sama persis dengan UID dari Authentication.

Contoh isi `users/{UID_PENGELOLA}`:

```json
{
  "role": "pengelola"
}
```

Contoh isi `users/{UID_MAINTENANCE}`:

```json
{
  "role": "maintenance"
}
```

Jangan membuat role berdasarkan input pengguna di halaman login; role harus diberikan administrator.

## 3. Koleksi yang digunakan

- `ph-activity`: dibuat oleh ESP32. Field yang dibaca web: `ph`, `deviceId`, `location`, `timestamp`.
- `maintenance-logs`: dibuat dari halaman Pemeliharaan Sensor. Field: `location`, `deviceId`, `issue`, `action`, `status`, `createdBy`, `createdAt`.
- `users`: dokumen profil role untuk setiap akun login.

## 4. Aturan Firestore

Revisi aplikasi memerlukan aturan yang mengizinkan:

- Pengguna login membaca dokumen `users/{uid}` miliknya sendiri.
- Pengelola dan maintenance membaca `ph-activity`.
- Akun ESP32 yang terautentikasi membuat dokumen baru di `ph-activity`.
- Pengelola dan maintenance membaca `maintenance-logs`; hanya maintenance yang boleh membuat catatan perbaikan.

Aturan persisnya harus disesuaikan dengan aturan yang sudah berjalan dan email akun autentikasi yang dipakai ESP32. Jangan mengaktifkan akses publik `allow read, write: if true` untuk database yang digunakan sungguhan.
