/// Livestock breed constants for ShowTrackAI
/// Contains common show breeds organized by species for FFA/4-H projects
library livestock_breeds;

import '../models/animal_species.dart';

/// Map of animal species to their most common show breeds
/// Includes both purebred and crossbred options for each species
const Map<AnimalSpecies, List<String>> livestockBreeds = {
  // CATTLE BREEDS
  // Most popular show breeds in youth livestock programs
  AnimalSpecies.cattle: [
    // Beef Breeds - Most Common in Shows
    'Angus',
    'Hereford', 
    'Shorthorn',
    'Simmental',
    'Charolais',
    'Limousin',
    'Maine-Anjou',
    'Chianina',
    'Gelbvieh',
    
    // Dairy Breeds - Common in 4-H/FFA
    'Holstein',
    'Jersey',
    'Guernsey',
    'Ayrshire',
    'Brown Swiss',
    'Milking Shorthorn',
    
    // Specialty/Heritage Breeds
    'Brahman',
    'Santa Gertrudis',
    'Brangus',
    'Beefmaster',
    'Red Angus',
    'Polled Hereford',
    'Devon',
    'Highland',
    
    // Always include these options
    'Crossbred',
    'Commercial',
    'Other',
  ],

  // GOAT BREEDS  
  // Market goats and breeding does popular in youth shows
  AnimalSpecies.goats: [
    // Meat Breeds - Most Common in Market Shows
    'Boer',
    'Kiko', 
    'Spanish',
    'Myotonic (Fainting)',
    'Savanna',
    'Brush Goat',
    
    // Dairy Breeds - Popular in 4-H/FFA
    'Nubian',
    'LaMancha', 
    'Alpine',
    'Saanen',
    'Toggenburg',
    'Oberhasli',
    'Nigerian Dwarf',
    
    // Fiber Breeds
    'Angora',
    'Cashmere',
    
    // Show Wethers (Common Crosses)
    'Boer Cross',
    'Kiko Cross',
    'Percentage Boer',
    
    // Always include these options
    'Crossbred',
    'Commercial',
    'Other',
  ],

  // SHEEP BREEDS
  // Market lambs and breeding ewes for youth livestock
  AnimalSpecies.sheep: [
    // Terminal Sire Breeds - Popular for Market Lambs
    'Hampshire',
    'Suffolk',
    'Southdown',
    'Oxford',
    'Shropshire',
    'Tunis',
    
    // Maternal Breeds - Common for Breeding Projects
    'Rambouillet',
    'Columbia',
    'Corriedale',
    'Romney',
    'Targhee',
    'Polypay',
    
    // Medium Wool Breeds
    'Cheviot',
    'Montadale',
    'North Country Cheviot',
    
    // Fine Wool Breeds
    'Merino',
    'Cormo',
    
    // Hair Breeds - Growing Popularity
    'Dorper',
    'Katahdin',
    'St. Croix',
    'Barbados Blackbelly',
    
    // Specialty/Show Breeds
    'Leicester Longwool',
    'Lincoln',
    'Cotswold',
    'Jacob',
    
    // Always include these options
    'Crossbred',
    'Commercial',
    'Other',
  ],

  // SWINE BREEDS
  // Market hogs and breeding gilts for youth shows
  AnimalSpecies.swine: [
    // Terminal Breeds - Most Common for Market Hogs
    'Hampshire',
    'Duroc',
    'Yorkshire',
    'Landrace',
    'Pietrain',
    'Poland China',
    
    // Maternal Breeds - Popular for Breeding Projects
    'Chester White',
    'Spotted',
    'Berkshire',
    
    // Specialty Breeds - Growing in Youth Programs
    'Mangalitsa',
    'Gloucestershire Old Spots',
    'Tamworth',
    'Large Black',
    'Ossabaw Island Hog',
    
    // Commercial Classifications
    'Crossbred Barrow',
    'Crossbred Gilt',
    'F1 Cross',
    'Terminal Cross',
    
    // Always include these options
    'Crossbred',
    'Commercial',
    'Other',
  ],

  // POULTRY BREEDS
  // Chickens, turkeys, ducks, and geese for youth projects
  AnimalSpecies.poultry: [
    // CHICKENS - Egg Production Breeds
    'White Leghorn',
    'Rhode Island Red',
    'New Hampshire',
    'Australorp',
    'Plymouth Rock',
    'Wyandotte',
    'Orpington',
    
    // CHICKENS - Meat Production Breeds
    'Cornish Cross',
    'Jersey Giant',
    'Brahma',
    'Cochin',
    
    // CHICKENS - Dual Purpose Breeds
    'Rhode Island Red',
    'Barred Plymouth Rock',
    'Buff Orpington',
    'Sussex',
    'Dominique',
    
    // TURKEYS
    'Broad Breasted Bronze',
    'Broad Breasted White',
    'Bourbon Red',
    'Narragansett',
    'Royal Palm',
    
    // DUCKS
    'Pekin',
    'Rouen',
    'Khaki Campbell',
    'Indian Runner',
    'Muscovy',
    
    // GEESE
    'Embden',
    'Toulouse',
    'Chinese',
    'African',
    
    // Always include these options
    'Crossbred',
    'Mixed Breed',
    'Other',
  ],

  // RABBIT BREEDS
  // Market rabbits and breeding does for youth programs
  AnimalSpecies.rabbits: [
    // Meat Breeds - Most Common for Market Rabbits
    'New Zealand White',
    'New Zealand Red',
    'Californian',
    'Flemish Giant',
    'Champagne D\'Argent',
    'American Chinchilla',
    'Satin',
    
    // Medium Breeds - Popular in 4-H/FFA
    'Rex',
    'Mini Rex',
    'Dutch',
    'English Lop',
    'French Lop',
    'Holland Lop',
    'Mini Lop',
    
    // Small Breeds - Good for Beginners
    'Netherland Dwarf',
    'Polish',
    'Himalayan',
    'Florida White',
    
    // Specialty Breeds
    'Angora (English)',
    'Angora (French)',
    'Angora (German)',
    'Lionhead',
    'Jersey Wooly',
    'American Fuzzy Lop',
    
    // Rare/Heritage Breeds
    'Silver Fox',
    'American',
    'Blanc de Hotot',
    'Creme D\'Argent',
    
    // Always include these options
    'Crossbred',
    'Mixed Breed',
    'Other',
  ],
};

/// Helper function to get breeds for a specific species
List<String> getBreedsForSpecies(AnimalSpecies species) {
  return livestockBreeds[species] ?? ['Other'];
}

/// Helper function to check if a breed is valid for a species
bool isValidBreedForSpecies(AnimalSpecies species, String breed) {
  return livestockBreeds[species]?.contains(breed) ?? false;
}

/// Popular crossbred combinations by species
/// Used for suggesting common cross combinations
const Map<AnimalSpecies, List<String>> popularCrosses = {
  AnimalSpecies.cattle: [
    'Angus x Hereford',
    'Angus x Simmental', 
    'Hereford x Simmental',
    'Charolais x Angus',
    'Limousin x Angus',
    'Maine-Anjou x Angus',
  ],
  
  AnimalSpecies.goats: [
    'Boer x Spanish',
    'Boer x Kiko',
    'Percentage Boer',
    'Nubian x Boer',
    '75% Boer',
    '50% Boer',
  ],
  
  AnimalSpecies.sheep: [
    'Hampshire x Suffolk',
    'Hampshire x Columbia', 
    'Suffolk x Rambouillet',
    'Dorper x Hair Sheep',
    'Terminal x Maternal',
  ],
  
  AnimalSpecies.swine: [
    'Yorkshire x Hampshire',
    'Duroc x Yorkshire',
    'Hampshire x Duroc',
    'Landrace x Hampshire',
    'Terminal Cross',
  ],
  
  AnimalSpecies.poultry: [
    'Production Red',
    'Red Sex-Link',
    'Black Sex-Link',
    'Commercial Broiler',
    'Heritage Cross',
  ],
  
  AnimalSpecies.rabbits: [
    'New Zealand x Californian',
    'Rex x New Zealand',
    'Flemish x New Zealand',
    'Meat Cross',
    'Commercial Cross',
  ],
};

/// Breed categories for filtering and organization
const Map<String, List<String>> breedCategories = {
  // Cattle Categories
  'beef_cattle': [
    'Angus', 'Hereford', 'Shorthorn', 'Simmental', 'Charolais', 
    'Limousin', 'Maine-Anjou', 'Chianina', 'Gelbvieh', 'Red Angus'
  ],
  'dairy_cattle': [
    'Holstein', 'Jersey', 'Guernsey', 'Ayrshire', 'Brown Swiss', 
    'Milking Shorthorn'
  ],
  
  // Goat Categories  
  'meat_goats': [
    'Boer', 'Kiko', 'Spanish', 'Myotonic (Fainting)', 'Savanna'
  ],
  'dairy_goats': [
    'Nubian', 'LaMancha', 'Alpine', 'Saanen', 'Toggenburg', 
    'Oberhasli', 'Nigerian Dwarf'
  ],
  
  // Sheep Categories
  'terminal_sheep': [
    'Hampshire', 'Suffolk', 'Southdown', 'Oxford', 'Shropshire'
  ],
  'maternal_sheep': [
    'Rambouillet', 'Columbia', 'Corriedale', 'Romney', 'Polypay'
  ],
  'hair_sheep': [
    'Dorper', 'Katahdin', 'St. Croix', 'Barbados Blackbelly'
  ],
  
  // Swine Categories
  'terminal_swine': [
    'Hampshire', 'Duroc', 'Pietrain'
  ],
  'maternal_swine': [
    'Yorkshire', 'Landrace', 'Chester White', 'Spotted'
  ],
  
  // Poultry Categories
  'laying_hens': [
    'White Leghorn', 'Rhode Island Red', 'New Hampshire', 'Australorp'
  ],
  'meat_birds': [
    'Cornish Cross', 'Jersey Giant', 'Brahma'
  ],
  'turkeys': [
    'Broad Breasted Bronze', 'Broad Breasted White', 'Bourbon Red'
  ],
  
  // Rabbit Categories
  'meat_rabbits': [
    'New Zealand White', 'New Zealand Red', 'Californian', 'Flemish Giant'
  ],
  'pet_rabbits': [
    'Holland Lop', 'Netherland Dwarf', 'Mini Rex', 'Lionhead'
  ],
};