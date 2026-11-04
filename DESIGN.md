# DESIGN.md — Gawa Card Battle Visual System

## Design Philosophy: "Manga Chaos Meets Tactile Arcade"
หลีกเลี่ยงรูปแบบ "AI Slop" ทั่วไป (เช่น กรอบสี่เหลี่ยมมืดมนเรียบๆ ที่ใส่เส้นเรืองแสงนีออนสีฟ้า-ม่วงซ้ำซากโดยไร้จุดเด่น) โดยเปลี่ยนมาใช้สไตล์ **"Manga Chaos Arcade"** ที่มีชีวิตชีวา สนุกสนาน คมชัด มีน้ำหนัก มีมิติแบบการ์ตูนโชเน็น และให้สัมผัสตอบสนองทันที (Tactile Game Feel)

---

## 🎨 Color Tokens & Palette

### 1. Canvas & Structural Inks
- `Ink.Deep`: `Color3.fromRGB(18, 14, 28)` — พื้นหลังหลักมืดลึกคล้ายหมึกมังงะ
- `Ink.Panel`: `Color3.fromRGB(28, 24, 46)` — พื้นหลังหน้าต่าง UI มีความทึบแสงและคอนทราสต์ชัดเจน
- `Ink.Border`: `Color3.fromRGB(48, 40, 75)` — ขอบแบ่งส่วนภายใน

### 2. Kinetic Accent Colors
- `Accent.Gold`: `Color3.fromRGB(255, 214, 10)` — สกุลเงิน Gold, เลเวล, ไฮไลต์ความสำเร็จ
- `Accent.Slime`: `Color3.fromRGB(0, 240, 160)` — หลอด HP ฮีโร่เรา, ปุ่มกระทำหลัก (Action)
- `Accent.Magenta`: `Color3.fromRGB(255, 64, 168)` — หลอดกาวไม้ตาย (Glue Ult), เอฟเฟกต์สุดปั่น
- `Accent.Crimson`: `Color3.fromRGB(255, 59, 86)` — ฝั่งศัตรู, ดาเมจ, ปุ่มยกเลิก/ยอมแพ้
- `Accent.Cyan`: `Color3.fromRGB(56, 175, 255)` — มานาคริสตัล, แท็บและฟิลเตอร์

### 3. Card Rarity Signature Colors
- ⚪ **Common**: `Color3.fromRGB(150, 155, 170)` (เทาเหล็ก คมชัด)
- 🔵 **Rare**: `Color3.fromRGB(45, 150, 255)` (น้ำเงินไฟฟ้าสด)
- 🟡 **Legendary**: `Color3.fromRGB(255, 195, 25)` (ทองอร่าม อิ่มตัวสูง)
- 🟣 **Glue (กาวพันปี)**: Dynamic Rainbow Gradient + Magenta (ชมพูรุ้งกาว หมุนวน)

---

## 📐 Shape, Hierarchy & Typography

### 1. Shape Language
- **Tactile Squircle**: ขอบมนที่ไม่อ่อนยวบเกินไป (`UICorner.CornerRadius = UDim.new(0, 16)` สำหรับการ์ดและปุ่มหลัก, `UDim.new(0, 24)` สำหรับโมดอล)
- **Comic Outlines (`UIStroke`)**: ใช้ขอบหนา 2.5 - 3.5px เพื่อเน้นความคมชัดแบบคอมมิก ไม่ปล่อยให้องค์ประกอบกลืนไปกับฉากหลัง 3D
- **Sticker Badges & Ribbons**: ระดับความหายากและสเตตัสใช้ป้ายสไตล์สติกเกอร์เอียงเล็กน้อย (-3 ถึง +5 องศา) เพื่อเพิ่มความซุกซนและลดความแข็งกระด้าง

### 2. Typography Hierarchy
- **Header / Numbers**: `Enum.Font.GothamBlack` / `Enum.Font.FredokaOne` — อ้วน หนา ชัด อ่านง่ายทันทีแม้ในจอมือถือ
- **Body / Descriptions**: `Enum.Font.GothamBold` / `Enum.Font.GothamMedium` — มีช่องไฟชัดเจน พร้อมสีข้อความคอนทราสต์สูง (`Color3.fromRGB(245, 245, 255)`)

---

## ⚡ Motion & Micro-Interactions (Anti-Slop Craft)
- **Button Hover**: ขยายสเกล `1.06x` นุ่มนวลด้วย `Enum.EasingStyle.Back` (Dir: Out, 0.2s)
- **Button Click / Punch**: ยุบตัวลง `0.9x` ใน 0.08s แล้วเด้งกลับ `1.0x` (Tactile Spring)
- **Damage Numbers**: ลอยขึ้นพร้อมขยายขนาดแบบเด้ง (Punch Pop) สุ่มการเอียง -12 ถึง +12 องศา
- **Screen Transitions**: HUD ยุบตัวและสไลด์ออกนอกจอเมื่อเข้าสู่การดวล และสไลด์กลับมาอย่างลื่นไหลเมื่อจบเกม
