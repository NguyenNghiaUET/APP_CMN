============================================
  QXlsx — BẮT BUỘC để build được ProjectTestCap
============================================

CMake báo lỗi "QXlsx chưa có" nếu chưa có thư mục third_party/QXlsx.
Làm đúng các bước sau:

1. Tải file zip:
   https://github.com/QtExcel/QXlsx/archive/refs/tags/v1.4.6.zip

2. Giải nén file zip, bạn sẽ có thư mục "QXlsx-1.4.6".

3. Mở thư mục QXlsx-1.4.6. Bên trong có thư mục con tên "QXlsx".
   Copy CẢ THƯ MỤC "QXlsx" đó vào:
   D:\ProjectTestCap\third_party\

   Kết quả phải tồn tại file:
   D:\ProjectTestCap\third_party\QXlsx\CMakeLists.txt

   (KHÔNG copy thư mục QXlsx-1.4.6, chỉ copy thư mục con "QXlsx" bên trong.)

4. Chạy lại CMake / Build trong Qt Creator.

============================================
