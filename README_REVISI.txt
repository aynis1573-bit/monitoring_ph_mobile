REVISI UI MONITORING pH AIR

Cara mencoba:
1. Buat salinan/backup folder proyek lama terlebih dahulu.
2. Ekstrak ZIP ini ke folder baru (jangan menimpa proyek lama).
3. Buka folder hasil ekstrak di VS Code.
4. Jalankan: flutter pub get
5. Jalankan: flutter analyze
6. Jalankan: flutter run -d chrome

Yang disertakan di revisi ini:
- Menu Dashboard, Grafik, Riwayat, Notifikasi, Laporan, dan Pemeliharaan Sensor.
- Halaman notifikasi memperingatkan nilai pH di luar rentang acuan 6,5-8,5 dan titik yang belum memiliki data.
- Halaman laporan menghitung rata-rata dan ringkasan dari dokumen yang dimuat. Saat ini FirebaseSensorService membatasi query ke 60 dokumen terbaru, sehingga ringkasan belum merupakan laporan bulanan lengkap.
- Informasi pH disertakan di dashboard.
- Struktur Firestore yang digunakan tetap koleksi ph-activity dengan field ph, deviceId, location, timestamp.

Batasan penting:
- Login dan pemisahan akses Pengelola/Maintenance belum diaktifkan dalam revisi ini. Untuk keamanan, fitur ini perlu Firebase Authentication, dokumen role pengguna, dan Firestore Security Rules; jangan mengandalkan menu yang disembunyikan di UI saja.
- Status 'belum ada data' tidak memastikan sensor rusak/terputus. Untuk deteksi offline, ESP32 perlu mengirim heartbeat/status dan web perlu mengecek waktu terakhir.
- Catatan kerusakan/perbaikan belum disimpan; diperlukan koleksi khusus.
- Pastikan kode ESP32 mengirim timestamp sebagai Firestore timestampValue dan field yang konsisten.


Fitur tambahan terbaru: Firebase Authentication login, role Pengelola/Maintenance dari dokumen users/{UID}, popup peringatan pH, dan popup data stale untuk maintenance. Lihat LOGIN_DAN_POPUP_SETUP.md sebelum menjalankan.


PERBAIKAN MENU PEMELIHARAAN SENSOR:
- Menu Pemeliharaan Sensor kini ditampilkan untuk akun Pengelola maupun Maintenance.
- Halaman ini saat ini bersifat pemantauan status data terakhir dan panduan perawatan, belum menyimpan catatan perbaikan ke Firestore.
- Popup peringatan jika data lama/tidak diperbarui tetap diaktifkan khusus untuk role Maintenance.
- Laporan tetap tampil untuk role Pengelola.
