# Login dan notifikasi popup Monitoring pH Air

## Yang ditambahkan

- Login menggunakan Firebase Authentication Email/Password.
- Role dibaca dari Firestore `users/{UID}`; pengguna tidak dapat memilih role sendiri dari halaman login.
- Role `pengelola` melihat Dashboard, Grafik, Notifikasi, Riwayat, dan Laporan.
- Role `maintenance` melihat Dashboard, Grafik, Notifikasi, Riwayat, dan Pemeliharaan Sensor.
- Popup muncul saat pH baru berubah ke luar rentang 6,5–8,5.
- Untuk maintenance, popup juga muncul jika data dari titik yang sebelumnya memiliki pembacaan tidak diperbarui selama lebih dari 5 menit. Titik yang tidak pernah punya data tidak langsung dianggap rusak.

## Langkah konfigurasi wajib

1. Firebase Console → Authentication → Sign-in method → aktifkan Email/Password.
2. Authentication → Users → tambahkan user untuk pengelola dan maintenance.
3. Untuk masing-masing pengguna, salin UID lalu buat dokumen `users` dengan Document ID sama dengan UID.
4. Isi dokumen pengelola dengan `{ "role": "pengelola" }` dan maintenance dengan `{ "role": "maintenance" }`.
5. Di root proyek, jalankan `flutter pub get`, `flutter analyze`, lalu `flutter run -d chrome`.
6. Jika Firebase Rules menolak login atau baca data, sesuaikan aturan Firestore. Minimal pengguna yang sudah login harus dapat membaca dokumen profilnya sendiri dan membaca `ph-activity` sesuai role. Jangan mengaktifkan akses publik ke seluruh database.

## Contoh aturan Firestore yang ketat sebagai titik awal

Contoh ini mengasumsikan akun ESP32 juga memakai Firebase Authentication dan memiliki dokumen `users/{UID}` dengan `role: "device"`. Periksa kembali aturan yang sudah ada sebelum mengganti rules di Firebase Console.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }

    function myRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }

    match /users/{uid} {
      allow read: if signedIn() && request.auth.uid == uid;
      // Role ditetapkan admin melalui Firebase Console, bukan dari aplikasi.
      allow write: if false;
    }

    match /ph-activity/{readingId} {
      allow read: if signedIn() && myRole() in ['pengelola', 'maintenance'];
      allow create: if signedIn() && myRole() == 'device';
      allow update, delete: if false;
    }

    match /maintenance-logs/{logId} {
      allow read: if signedIn() && myRole() in ['pengelola', 'maintenance'];
      allow create: if signedIn() && myRole() == 'maintenance';
      allow update, delete: if false;
    }
  }
}
```

**Penting:** jika firmware ESP32 kamu menggunakan email akun pengiriman yang sudah ada, buat dokumen `users/{UID_akun_ESP32}` dengan role `device` sebelum menerapkan aturan contoh di atas. Jangan menyimpan password atau API key di repository publik.

## Catatan deteksi sensor

Popup offline mendeteksi tidak adanya pembaruan timestamp lebih dari 5 menit untuk titik yang mempunyai data sebelumnya. Itu indikator komunikasi/data tidak diperbarui; bukan bukti mutlak sensor fisik rusak. Untuk diagnosis lebih pasti, firmware sebaiknya mengirim heartbeat dan status sensor terpisah.


## Uji popup peringatan

- Login sebagai pengelola atau maintenance.
- Pastikan ada data terbaru di `ph-activity` dengan `location` persis salah satu dari `Depot Utama`, `Toren Cabang 1`, atau `Toren Cabang 2`.
- Popup pH akan muncul saat aplikasi menerima keadaan pH di bawah 6,5 atau di atas 8,5. Popup hanya muncul saat keadaan berubah menjadi di luar rentang, bukan pada setiap refresh ketika peringatan yang sama masih aktif.
- Untuk uji sensor stale, login sebagai maintenance dan gunakan titik yang sebelumnya memang punya data. Jika `timestamp` terakhir lebih tua dari 5 menit, aplikasi memberi popup bahwa data tidak diperbarui. Ini hanya indikator data/komunikasi tertunda.
- Jika ingin menguji tanpa mengubah perangkat, gunakan dokumen uji terpisah di koleksi `ph-activity` dengan field `ph` (number), `deviceId` (string), `location` (string) dan `timestamp` (Firestore timestamp). Hapus dokumen uji setelah selesai.

Popup tampil saat halaman web sedang terbuka. Ini bukan notifikasi browser/background ketika web ditutup.
