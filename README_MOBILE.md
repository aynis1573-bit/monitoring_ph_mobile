# Monitoring pH Air — Versi Mobile Android

Ini adalah salinan proyek Flutter terpisah yang dioptimalkan untuk layar ponsel. Folder ini dibuat dari revisi dengan Login, Popup Notifikasi, Riwayat, Laporan, dan Pemeliharaan Sensor. Folder web utama `D:\monitoring_ph` tidak diubah oleh proyek ini.

## Perubahan khusus mobile

- Navigasi bawah diringkas menjadi Beranda, Grafik, Riwayat, Notifikasi, dan Lainnya.
- Menu Laporan (untuk role `pengelola`) dan Pemeliharaan Sensor dapat dibuka dari menu Lainnya.
- Dashboard menampilkan kartu titik monitoring secara bertumpuk agar lebih mudah dibaca di layar sempit.
- Login menggunakan layout yang dapat digulir pada layar ponsel.
- Proyek tetap menggunakan konfigurasi Firebase yang sama agar membaca koleksi `ph-activity` dan role di `users`.

## Menjalankan di Windows PowerShell

1. Ekstrak ZIP ini ke `D:\monitoring_ph_mobile`.
2. Buka PowerShell dan jalankan:

```powershell
cd D:\monitoring_ph_mobile
flutter pub get
flutter analyze
flutter devices
```

3. Pastikan emulator Android sudah menyala. Jalankan aplikasi dengan ID perangkat yang ditampilkan oleh `flutter devices`, misalnya:

```powershell
flutter run -d emulator-5554
```

Jika ingin melihatnya di Chrome, gunakan:

```powershell
flutter run -d chrome
```

## Firebase

Aplikasi menggunakan Firebase Authentication dan Firestore yang telah dikonfigurasi pada proyek sumber. Pastikan Android app tetap terdaftar di Firebase dengan application ID `com.example.monitoring_ph`, dan dokumen `users/{UID}` berisi field `role` dengan nilai `pengelola` atau `maintenance`.

Jangan mengunggah file yang berisi password/token ke repository publik. File konfigurasi Firebase client yang disertakan harus digunakan bersama Firestore Rules yang sesuai.

## Catatan Build Android

Peringatan Kotlin Gradle Plugin (KGP) yang muncul saat build adalah peringatan kompatibilitas untuk rilis Flutter mendatang, bukan otomatis berarti build gagal. Jika build berhenti, lihat bagian paling bawah output untuk `FAILURE: Build failed with an exception` dan error spesifiknya; folder terpisah ini menjaga sumber web utama tetap aman, tetapi tidak dengan sendirinya memperbaiki error Gradle yang sebenarnya.
