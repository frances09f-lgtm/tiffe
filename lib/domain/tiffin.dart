enum Plan { none, daily, double }

class Bhaji {
  final String id, name, description, image;
  final bool available;
  const Bhaji(
    this.id,
    this.name,
    this.description,
    this.image, {
    this.available = true,
  });
}

class Pricing {
  static const extraBhaji = 10,
      oneTime = 80,
      monthlyDelivery = 199,
      oneTimeDelivery = 20;
  static int deliveryFor(Plan plan) =>
      plan == Plan.none ? oneTimeDelivery : monthlyDelivery;
  static int extras(int count) => count > 2 ? (count - 2) * extraBhaji : 0;
  static int monthly(Plan plan) => switch (plan) {
    Plan.daily => 1500,
    Plan.double => 3000,
    Plan.none => 0,
  };
  static int quantity(Plan plan) => plan == Plan.double ? 2 : 1;
  static bool sweet(DateTime date, Plan plan, {bool paused = false}) =>
      date.weekday == DateTime.sunday && plan != Plan.none && !paused;
  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

const menu = [
  Bhaji(
    'batata',
    'Batata Bhaji',
    'Turmeric, curry leaves & a little love',
    'assets/food/batata.jpg',
  ),
  Bhaji(
    'matki',
    'Matki Usal',
    'Sprouted moth beans, home-style masala',
    'assets/food/matki.jpg',
  ),
  Bhaji(
    'baingan',
    'Baingan Masala',
    'Tender aubergine in a rich masala',
    'assets/food/baingan.jpg',
  ),
  Bhaji(
    'cabbage',
    'Cabbage Bhaji',
    'Light, fresh & gently spiced',
    'assets/food/cabbage.jpg',
  ),
  Bhaji(
    'vatana',
    'Vatana',
    'Green peas in a comforting curry',
    'assets/food/vatana.jpg',
  ),
  Bhaji(
    'mix',
    'Mix Veg',
    'A colourful bowl of seasonal goodness',
    'assets/food/mix.jpg',
  ),
  Bhaji(
    'mirchi',
    'Bharli Mirchi',
    'Stuffed chillies with peanut masala',
    'assets/food/mirchi.jpg',
  ),
  Bhaji(
    'aloo',
    'Aloo Matar',
    'The familiar potato & pea favourite',
    'assets/food/aloo.jpg',
  ),
];
