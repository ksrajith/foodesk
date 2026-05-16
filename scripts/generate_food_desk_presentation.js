const PptxGenJS = require("pptxgenjs");

const pptx = new PptxGenJS();
pptx.layout = "LAYOUT_WIDE"; // 13.33 x 7.5
pptx.author = "FoodDesk Team";
pptx.company = "FoodDesk";
pptx.subject = "FoodDesk product presentation";
pptx.title = "FoodDesk - 5 Minute Project Presentation";
pptx.lang = "en-US";

const colors = {
  bg: "F7FAFC",
  primary: "0F4C81",
  accent: "2E8B57",
  text: "1F2937",
  lightText: "6B7280",
  white: "FFFFFF",
};

function addHeader(slide, title, subtitle) {
  slide.background = { color: colors.bg };
  slide.addShape(pptx.ShapeType.rect, {
    x: 0,
    y: 0,
    w: 13.33,
    h: 0.9,
    fill: { color: colors.primary },
    line: { color: colors.primary },
  });
  slide.addText(title, {
    x: 0.45,
    y: 0.18,
    w: 9.5,
    h: 0.4,
    fontFace: "Calibri",
    fontSize: 20,
    bold: true,
    color: colors.white,
  });
  slide.addText(subtitle, {
    x: 0.45,
    y: 0.95,
    w: 12.4,
    h: 0.35,
    fontFace: "Calibri",
    fontSize: 13,
    color: colors.lightText,
  });
}

function addBulletList(slide, items, yStart = 1.6) {
  const bulletText = items.map((item) => ({ text: item, options: { bullet: { indent: 18 } } }));
  slide.addText(bulletText, {
    x: 0.8,
    y: yStart,
    w: 12.0,
    h: 4.8,
    fontFace: "Calibri",
    fontSize: 21,
    color: colors.text,
    paraSpaceAfterPt: 16,
    breakLine: true,
  });
}

// Slide 1: Title
{
  const slide = pptx.addSlide();
  slide.background = { color: colors.primary };
  slide.addText("FoodDesk", {
    x: 0.8,
    y: 1.6,
    w: 8.0,
    h: 0.9,
    fontFace: "Calibri",
    fontSize: 52,
    bold: true,
    color: colors.white,
  });
  slide.addText("Simplifying daily meal ordering for offices", {
    x: 0.85,
    y: 2.55,
    w: 9.8,
    h: 0.5,
    fontFace: "Calibri",
    fontSize: 24,
    color: "D1E8FF",
  });

  slide.addShape(pptx.ShapeType.roundRect, {
    x: 0.85,
    y: 3.45,
    w: 6.6,
    h: 1.7,
    radius: 0.08,
    fill: { color: colors.white, transparency: 5 },
    line: { color: colors.white, transparency: 100 },
  });
  slide.addText("5-minute project presentation", {
    x: 1.2,
    y: 4.0,
    w: 6.0,
    h: 0.4,
    fontFace: "Calibri",
    fontSize: 20,
    bold: true,
    color: colors.primary,
  });
  slide.addText("Problem • Solution • Product Value • Roadmap", {
    x: 1.2,
    y: 4.45,
    w: 6.0,
    h: 0.35,
    fontFace: "Calibri",
    fontSize: 14,
    color: colors.lightText,
  });
}

// Slide 2: Problem
{
  const slide = pptx.addSlide();
  addHeader(slide, "The Problem", "Why meal ordering breaks in many organizations");
  addBulletList(slide, [
    "Manual ordering through chat groups and spreadsheets causes frequent mistakes.",
    "Employees miss ordering deadlines and suppliers receive incomplete counts.",
    "No role-based workflow: admin, supplier, and customer tasks get mixed.",
    "Little visibility on order status, late requests, and historical reports.",
    "Business impact: wasted time, wrong meals delivered, and avoidable cost.",
  ]);
}

// Slide 3: Solution
{
  const slide = pptx.addSlide();
  addHeader(slide, "FoodDesk Solution", "A role-based mobile workflow built on Flutter + Firebase");
  addBulletList(slide, [
    "Single app with dedicated experiences for Admin, Supplier, and Customer.",
    "Firebase Authentication + approval flow for secure and controlled onboarding.",
    "Live product/menu management and daily order lifecycle tracking.",
    "Push notifications for reminders and late-order handling.",
    "Generated reports (PDF) for operational and management visibility.",
  ]);
}

// Slide 4: Product walkthrough
{
  const slide = pptx.addSlide();
  addHeader(slide, "How the Product Works", "End-to-end software flow");
  addBulletList(slide, [
    "1) User signs up/logs in; account is validated by role and approval status.",
    "2) Supplier publishes meal options and order-before rules.",
    "3) Customers place meal orders within defined windows.",
    "4) Admin monitors pending registrations, orders, and totals dashboard.",
    "5) Notifications + history screens keep all stakeholders synchronized.",
  ]);
}

// Slide 5: Architecture and stack
{
  const slide = pptx.addSlide();
  addHeader(slide, "Architecture & Tech Stack", "Built for speed, reliability, and easy maintenance");

  slide.addShape(pptx.ShapeType.roundRect, {
    x: 0.8,
    y: 1.5,
    w: 3.8,
    h: 2.0,
    radius: 0.06,
    fill: { color: "E7F0FA" },
    line: { color: "BBD5EE" },
  });
  slide.addText("Frontend", {
    x: 1.05,
    y: 1.75,
    w: 3.3,
    h: 0.35,
    bold: true,
    fontSize: 16,
    color: colors.primary,
  });
  slide.addText("Flutter\nRole-based screens\nForm validation + UX", {
    x: 1.05,
    y: 2.1,
    w: 3.3,
    h: 1.2,
    fontSize: 13,
    color: colors.text,
  });

  slide.addShape(pptx.ShapeType.roundRect, {
    x: 4.95,
    y: 1.5,
    w: 3.8,
    h: 2.0,
    radius: 0.06,
    fill: { color: "EAF8EF" },
    line: { color: "BCE4C8" },
  });
  slide.addText("Backend Services", {
    x: 5.2,
    y: 1.75,
    w: 3.3,
    h: 0.35,
    bold: true,
    fontSize: 16,
    color: colors.accent,
  });
  slide.addText("Firebase Auth\nCloud Firestore\nCloud Functions + Storage", {
    x: 5.2,
    y: 2.1,
    w: 3.3,
    h: 1.2,
    fontSize: 13,
    color: colors.text,
  });

  slide.addShape(pptx.ShapeType.roundRect, {
    x: 9.1,
    y: 1.5,
    w: 3.45,
    h: 2.0,
    radius: 0.06,
    fill: { color: "FFF4E8" },
    line: { color: "F2D3B4" },
  });
  slide.addText("Operations", {
    x: 9.35,
    y: 1.75,
    w: 2.95,
    h: 0.35,
    bold: true,
    fontSize: 16,
    color: "B45309",
  });
  slide.addText("FCM notifications\nPDF reporting\nAdmin settings controls", {
    x: 9.35,
    y: 2.1,
    w: 2.95,
    h: 1.2,
    fontSize: 13,
    color: colors.text,
  });

  slide.addText("Result: Cloud-native app with centralized data and real-time coordination.", {
    x: 0.8,
    y: 4.2,
    w: 11.9,
    h: 0.5,
    fontSize: 18,
    bold: true,
    color: colors.primary,
  });
}

// Slide 6: Business value
{
  const slide = pptx.addSlide();
  addHeader(slide, "Business Value", "Software outcomes delivered by FoodDesk");
  addBulletList(slide, [
    "Reduced manual coordination effort for daily meal operations.",
    "Fewer order errors through structured workflows and validation.",
    "Improved transparency via order history, totals, and registration tracking.",
    "Faster decision-making with exportable reports and real-time updates.",
    "Scalable foundation for future analytics, billing, and multi-location rollout.",
  ]);
}

// Slide 7: Roadmap
{
  const slide = pptx.addSlide();
  addHeader(slide, "Next Phase Roadmap", "Suggested evolution of the product");
  addBulletList(slide, [
    "Add digital payments and invoice reconciliation.",
    "Introduce analytics dashboard (popular meals, supplier performance, trends).",
    "Enable multi-office and multi-supplier configuration.",
    "Add SLA-based alerts for delayed meal fulfillment.",
    "Expand test automation and CI quality gates for faster releases.",
  ]);
}

// Slide 8: Closing
{
  const slide = pptx.addSlide();
  slide.background = { color: "EEF5FF" };
  slide.addShape(pptx.ShapeType.rect, {
    x: 0,
    y: 0,
    w: 13.33,
    h: 1.1,
    fill: { color: colors.primary },
    line: { color: colors.primary },
  });
  slide.addText("Thank You", {
    x: 0.7,
    y: 0.27,
    w: 4.0,
    h: 0.5,
    fontSize: 28,
    bold: true,
    color: colors.white,
  });
  slide.addText("FoodDesk - Smarter Daily Meal Operations", {
    x: 0.8,
    y: 2.0,
    w: 12,
    h: 0.6,
    fontSize: 30,
    bold: true,
    color: colors.primary,
  });
  slide.addText("Q&A", {
    x: 0.8,
    y: 3.1,
    w: 2.0,
    h: 0.5,
    fontSize: 26,
    bold: true,
    color: colors.accent,
  });
  slide.addText("Contact / Team details can be added here.", {
    x: 0.8,
    y: 3.8,
    w: 7.5,
    h: 0.35,
    fontSize: 14,
    color: colors.lightText,
  });
}

pptx.writeFile({ fileName: "FoodDesk_Project_Presentation.pptx" });
