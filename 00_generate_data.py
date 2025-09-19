#!/usr/bin/env python3
"""
Data Generation Script for Retail Analytics Challenge
Generates realistic dummy data for 5 years (2021-2025)
- 120+ products across multiple categories
- 320+ stores across different chains and regions  
- 1000+ sales records per year with seasonal patterns
- Inventory snapshots with realistic stock levels

Requirements: pip install faker pandas numpy
Usage: python 00_generate_data.py
"""

import csv
import random
import datetime
import os
from faker import Faker
import pandas as pd
import numpy as np
from pathlib import Path

# Configuration
fake = Faker('es_MX')
random.seed(42)  # For reproducible results
np.random.seed(42)

# Data volumes (exceeding minimum requirements)
NUM_PRODUCTOS = 125
NUM_TIENDAS = 325
YEARS = [2021, 2022, 2023, 2024, 2025]
START_DATE = datetime.date(2021, 1, 1)
END_DATE = datetime.date(2025, 12, 31)

# Business constants
CADENAS = ['SuperMax', 'MercadoPlus', 'TiendaFresh', 'CompraFácil']
FORMATOS = ['Super', 'Express', 'Hiper', 'Convenience']
REGIONES = ['Norte', 'Sur', 'Centro', 'Este', 'Oeste', 'Bajío']
ESTADOS = ['CDMX', 'Jalisco', 'Nuevo León', 'Puebla', 'Veracruz', 'Guanajuato', 'Michoacán']
CANALES = ['in-store', 'online', 'mobile']

# Product categories with realistic subcategories
CATEGORIAS_SAFE = {
    'Lacteos': ['Leche', 'Yogurt', 'Quesos', 'Mantequilla', 'Crema'],
    'Bebidas': ['Refrescos', 'Jugos', 'Agua', 'Bebidas Energeticas', 'Cafe'],
    'Snacks': ['Papas', 'Galletas', 'Dulces', 'Chocolates', 'Frutos Secos'],
    'Pan': ['Pan Dulce', 'Pan Salado', 'Tortillas', 'Pasteles', 'Bolleria'],
    'Verduras': ['Verduras Frescas', 'Verduras Congeladas', 'Ensaladas', 'Hierbas'],
    'Higiene': ['Cuidado Personal', 'Limpieza Hogar', 'Cuidado Bebe', 'Farmacia'],
    'Carnes': ['Res', 'Pollo', 'Cerdo', 'Pescado', 'Embutidos'],
    'Abarrotes': ['Enlatados', 'Granos', 'Aceites', 'Condimentos', 'Pasta']
}

def create_data_directory():
    """Create data directory if it doesn't exist"""
    Path('data').mkdir(exist_ok=True)
    print("📁 Created data directory")

def generate_productos():
    """Generate realistic product master data"""
    print("🛍️  Generating products...")
    
    productos = []
    marcas_por_categoria = {
        'Lacteos': ['Lala', 'Alpura', 'Santa Clara', 'Nestle', 'Danone'],
        'Bebidas': ['Coca-Cola', 'Pepsi', 'Jumex', 'Del Valle', 'Boing'],
        'Snacks': ['Sabritas', 'Barcel', 'Gamesa', 'Marinela', 'Ricolino'],
        'Pan': ['Bimbo', 'Wonder', 'Tia Rosa', 'Oroweat', 'Artesanal'],
        'Verduras': ['Del Monte', 'Green Giant', 'Local', 'Organico', 'Fresh'],
        'Higiene': ['P&G', 'Unilever', 'Colgate', 'Johnson', 'Nivea'],
        'Carnes': ['Pilgrims', 'Bachoco', 'Sukarne', 'San Rafael', 'Local'],
        'Abarrotes': ['La Costena', 'Herdez', 'McCormick', 'Knorr', 'Maggi']
    }
    
    producto_id = 1
    for categoria, subcategorias in CATEGORIAS_SAFE.items():
        # Generate 15-16 products per category
        productos_por_categoria = NUM_PRODUCTOS // len(CATEGORIAS_SAFE)
        
        for i in range(productos_por_categoria):
            subcategoria = random.choice(subcategorias)
            marca = random.choice(marcas_por_categoria[categoria])
            
            # Generate realistic product names
            if categoria == 'Lacteos':
                nombre = f"{marca} {subcategoria} {random.choice(['Natural', 'Light', 'Deslactosada', 'Entera'])}"
            elif categoria == 'Bebidas':
                nombre = f"{marca} {subcategoria} {random.choice(['600ml', '355ml', '1L', '2L'])}"
            elif categoria == 'Snacks':
                nombre = f"{marca} {subcategoria} {random.choice(['Original', 'Picante', 'Familiar', 'Individual'])}"
            else:
                nombre = f"{marca} {subcategoria} Premium"
            
            # Realistic pricing by category
            precio_base = {
                'Lacteos': (15, 45), 'Bebidas': (8, 35), 'Snacks': (5, 25),
                'Pan': (3, 20), 'Verduras': (10, 40), 'Higiene': (20, 80),
                'Carnes': (50, 200), 'Abarrotes': (8, 50)
            }
            
            precio_min, precio_max = precio_base[categoria]
            precio = round(random.uniform(precio_min, precio_max), 2)
            
            productos.append({
                'id_producto': producto_id,
                'sku': f'SKU{1000 + producto_id:04d}',
                'nombre_producto': nombre[:200],  # Respect DB constraint
                'marca': marca,
                'categoria': categoria,
                'subcategoria': subcategoria,
                'precio_sugerido': precio
            })
            producto_id += 1
    
    # Add a few extra products to exceed minimum
    while len(productos) < NUM_PRODUCTOS:
        categoria = random.choice(list(CATEGORIAS_SAFE.keys()))
        subcategoria = random.choice(CATEGORIAS_SAFE[categoria])
        marca = random.choice(marcas_por_categoria[categoria])
        
        productos.append({
            'id_producto': producto_id,
            'sku': f'SKU{1000 + producto_id:04d}',
            'nombre_producto': f"{marca} {subcategoria} Extra",
            'marca': marca,
            'categoria': categoria,
            'subcategoria': subcategoria,
            'precio_sugerido': round(random.uniform(10, 100), 2)
        })
        producto_id += 1
    
    df = pd.DataFrame(productos)
    df.to_csv('data/productos.csv', index=False, encoding='utf-8')
    print(f"✅ Generated {len(productos)} products")
    return productos

def generate_tiendas():
    """Generate realistic store master data"""
    print("🏪 Generating stores...")
    
    tiendas = []
    
    ciudades_safe = [
        'Mexico DF', 'Guadalajara', 'Monterrey', 'Puebla', 'Tijuana',
        'Leon', 'Juarez', 'Torreon', 'Queretaro', 'San Luis Potosi',
        'Merida', 'Aguascalientes', 'Morelia', 'Saltillo', 'Hermosillo',
        'Mexicali', 'Culiacan', 'Acapulco', 'Tlalnepantla', 'Cancun'
    ]
    
    for i in range(1, NUM_TIENDAS + 1):
        cadena = random.choice(CADENAS)
        formato = random.choice(FORMATOS)
        region = random.choice(REGIONES)
        estado = random.choice(ESTADOS)
        ciudad = random.choice(ciudades_safe)  # Use safe city names
        
        # Store size based on format
        superficie_map = {
            'Hiper': (2000, 5000),
            'Super': (800, 2000), 
            'Express': (200, 800),
            'Convenience': (50, 200)
        }
        superficie_min, superficie_max = superficie_map[formato]
        superficie = random.randint(superficie_min, superficie_max)
        
        # Opening date (stores opened over time)
        fecha_apertura = fake.date_between(start_date='-10y', end_date='-1y')
        
        tiendas.append({
            'id_tienda': i,
            'codigo_tienda': f'T{1000 + i:04d}',
            'nombre_tienda': f"{cadena} {ciudad}",
            'cadena': cadena,
            'formato': formato,
            'region': region,
            'ciudad': ciudad,
            'estado': estado,
            'superficie_m2': superficie,
            'fecha_apertura': fecha_apertura
        })
    
    df = pd.DataFrame(tiendas)
    df.to_csv('data/tiendas.csv', index=False, encoding='utf-8')
    print(f"✅ Generated {len(tiendas)} stores")
    return tiendas

def generate_ventas_with_patterns(productos, tiendas):
    """Generate sales data with realistic business patterns"""
    print("💰 Generating sales data with seasonal patterns...")
    
    # Create date range
    dates = pd.date_range(start=START_DATE, end=END_DATE, freq='D')
    
    # Pre-calculate store performance tiers
    tienda_performance = {}
    for tienda in tiendas:
        # Performance based on format and region
        base_performance = {
            'Hiper': 1.5, 'Super': 1.0, 'Express': 0.7, 'Convenience': 0.4
        }[tienda['formato']]
        
        region_multiplier = {
            'Centro': 1.2, 'Norte': 1.1, 'Sur': 0.9, 
            'Este': 1.0, 'Oeste': 0.95, 'Bajío': 0.85
        }[tienda['region']]
        
        tienda_performance[tienda['id_tienda']] = base_performance * region_multiplier
    
    # Pre-calculate product popularity (Pareto distribution)
    producto_popularity = {}
    for producto in productos:
        # Some categories are more popular
        category_multiplier = {
            'Bebidas': 1.3, 'Snacks': 1.2, 'Lacteos': 1.1, 'Pan': 1.0,
            'Abarrotes': 0.9, 'Verduras': 0.8, 'Carnes': 0.7, 'Higiene': 0.6
        }[producto['categoria']]
        
        # Pareto distribution: 20% of products drive 80% of sales
        popularity = np.random.pareto(0.5) * category_multiplier
        producto_popularity[producto['id_producto']] = min(popularity, 5.0)
    
    ventas_by_year = {year: [] for year in YEARS}
    
    for date in dates:
        year = date.year
        month = date.month
        day_of_week = date.weekday()  # 0=Monday, 6=Sunday
        
        # Seasonal factors
        seasonal_factor = 1.0
        if month == 12:  # December boost
            seasonal_factor = 1.8
        elif month == 11:  # November boost  
            seasonal_factor = 1.4
        elif month in [1, 2]:  # January/February dip
            seasonal_factor = 0.7
        elif month in [7, 8]:  # Summer boost
            seasonal_factor = 1.2
        
        # Day of week factors
        dow_factor = 1.0
        if day_of_week in [4, 5]:  # Friday, Saturday
            dow_factor = 1.3
        elif day_of_week == 6:  # Sunday
            dow_factor = 1.1
        elif day_of_week in [0, 1]:  # Monday, Tuesday
            dow_factor = 0.8
        
        # Holiday boost
        if date.month == 12 and date.day in [24, 25, 31]:
            seasonal_factor *= 1.5
        
        total_factor = seasonal_factor * dow_factor
        
        # Determine active stores for the day (not all stores sell every day)
        num_active_stores = max(50, int(len(tiendas) * random.uniform(0.6, 0.9)))
        active_stores = random.sample(tiendas, num_active_stores)
        
        for tienda in active_stores:
            store_performance = tienda_performance[tienda['id_tienda']]
            
            # Number of transactions per store per day
            base_transactions = int(store_performance * total_factor * random.uniform(5, 25))
            
            # Generate transactions
            for transaction_num in range(base_transactions):
                ticket_id = f"T{date.strftime('%Y%m%d')}{tienda['id_tienda']:03d}{transaction_num:03d}"
                
                # Items per transaction (1-8 items, weighted toward fewer items)
                items_in_transaction = min(8, max(1, int(np.random.exponential(2))))
                
                # Select products for this transaction
                transaction_products = random.choices(
                    productos, 
                    weights=[producto_popularity[p['id_producto']] for p in productos],
                    k=items_in_transaction
                )
                
                transaction_hour = random.choices(
                    range(8, 22),  # Store hours 8 AM to 10 PM
                    weights=[0.5, 0.7, 1.0, 1.2, 1.5, 1.8, 2.0, 1.8, 1.5, 1.2, 1.0, 0.8, 0.6, 0.4],
                    k=1
                )[0]
                
                for producto in transaction_products:
                    # Quantity (most items are 1-3 quantity)
                    cantidad = max(1, int(np.random.exponential(1.5)))
                    if cantidad > 10:
                        cantidad = random.randint(1, 3)
                    
                    # Price variation around suggested price
                    precio_base = producto['precio_sugerido']
                    precio_variation = random.uniform(0.9, 1.1)
                    precio_unitario = round(precio_base * precio_variation, 2)
                    
                    # Discount (occasional)
                    descuento_pct = 0
                    if random.random() < 0.15:  # 15% chance of discount
                        descuento_pct = random.choice([5, 10, 15, 20, 25])
                    
                    # Channel distribution
                    canal = random.choices(
                        CANALES,
                        weights=[85, 12, 3],  # Mostly in-store
                        k=1
                    )[0]
                    
                    ventas_by_year[year].append({
                        'id_producto': producto['id_producto'],
                        'id_tienda': tienda['id_tienda'],
                        'fecha': date.date(),
                        'hora': f"{transaction_hour:02d}:{random.randint(0, 59):02d}:00",
                        'ticket_id': ticket_id,
                        'cantidad': cantidad,
                        'precio_unitario': precio_unitario,
                        'descuento_pct': descuento_pct,
                        'canal': canal
                    })
    
    # Save sales data by year
    total_records = 0
    for year, ventas in ventas_by_year.items():
        if ventas:  # Only save if there's data
            df = pd.DataFrame(ventas)
            df.to_csv(f'data/ventas_{year}.csv', index=False, encoding='utf-8')
            total_records += len(ventas)
            print(f"  📅 {year}: {len(ventas):,} sales records")
    
    print(f"✅ Generated {total_records:,} total sales records")
    return ventas_by_year

def generate_inventarios(productos, tiendas):
    """Generate inventory snapshots"""
    print("📦 Generating inventory data...")
    
    inventarios = []
    
    # Generate monthly inventory snapshots
    for year in YEARS:
        for month in range(1, 13):
            # First day of each month
            fecha = datetime.date(year, month, 1)
            
            # Sample of stores (not all stores report inventory every month)
            reporting_stores = random.sample(tiendas, k=int(len(tiendas) * 0.7))
            
            for tienda in reporting_stores:
                # Sample of products (stores don't carry all products)
                store_products = random.sample(productos, k=int(len(productos) * 0.6))
                
                for producto in store_products:
                    # Stock levels based on product category and store format
                    categoria = producto['categoria']
                    formato = tienda['formato']
                    
                    # Base stock levels by category
                    base_stock = {
                        'Bebidas': (20, 200), 'Snacks': (15, 150), 'Lacteos': (10, 100),
                        'Pan': (5, 50), 'Abarrotes': (8, 80), 'Verduras': (5, 40),
                        'Carnes': (3, 30), 'Higiene': (10, 60)
                    }[categoria]
                    
                    # Format multiplier
                    format_multiplier = {
                        'Hiper': 3.0, 'Super': 1.5, 'Express': 1.0, 'Convenience': 0.5
                    }[formato]
                    
                    min_stock, max_stock = base_stock
                    min_stock = int(min_stock * format_multiplier)
                    max_stock = int(max_stock * format_multiplier)
                    
                    # Generate realistic inventory movement
                    stock_inicial = random.randint(min_stock, max_stock)
                    entradas = random.randint(0, max_stock // 2)
                    salidas = random.randint(0, min(stock_inicial + entradas, max_stock // 3))
                    stock_final = stock_inicial + entradas - salidas
                    
                    # Cost (typically 60-80% of suggested price)
                    costo_unitario = round(producto['precio_sugerido'] * random.uniform(0.6, 0.8), 2)
                    
                    inventarios.append({
                        'id_producto': producto['id_producto'],
                        'id_tienda': tienda['id_tienda'],
                        'fecha': fecha,
                        'stock_inicial': stock_inicial,
                        'stock_final': max(0, stock_final),  # Can't be negative
                        'entradas': entradas,
                        'salidas': salidas,
                        'costo_unitario': costo_unitario
                    })
    
    df = pd.DataFrame(inventarios)
    df.to_csv('data/inventarios.csv', index=False, encoding='utf-8')
    print(f"✅ Generated {len(inventarios):,} inventory records")

def generate_summary_report():
    """Generate a summary report of generated data"""
    print("\n📊 DATA GENERATION SUMMARY")
    print("=" * 50)
    
    # Read generated files and show stats
    files_info = []
    
    for file_path in Path('data').glob('*.csv'):
        df = pd.read_csv(file_path)
        files_info.append({
            'File': file_path.name,
            'Records': f"{len(df):,}",
            'Size (MB)': f"{file_path.stat().st_size / 1024 / 1024:.2f}"
        })
    
    summary_df = pd.DataFrame(files_info)
    print(summary_df.to_string(index=False))
    
    # Business insights
    print(f"\n🎯 BUSINESS DATA INSIGHTS")
    print(f"• Products: {NUM_PRODUCTOS} across {len(CATEGORIAS_SAFE)} categories")
    print(f"• Stores: {NUM_TIENDAS} across {len(CADENAS)} chains and {len(REGIONES)} regions")
    print(f"• Time period: {START_DATE} to {END_DATE} ({len(YEARS)} years)")
    print(f"• Seasonal patterns: December peaks, January/February dips")
    print(f"• Channel mix: ~85% in-store, ~12% online, ~3% mobile")
    print(f"• Discount frequency: ~15% of transactions")

def main():
    """Main execution function"""
    print("🚀 Starting Retail Analytics Data Generation")
    print("=" * 50)
    
    # Create directory structure
    create_data_directory()
    
    # Generate master data
    productos = generate_productos()
    tiendas = generate_tiendas()
    
    # Generate transactional data
    ventas = generate_ventas_with_patterns(productos, tiendas)
    generate_inventarios(productos, tiendas)
    
    # Generate summary
    generate_summary_report()
    
    print(f"\n✅ Data generation completed successfully!")
    print(f"📁 All files saved in 'data/' directory")
    print(f"🔄 Next steps:")
    print(f"   1. Run: psql -f sql/01_create_schema.sql")
    print(f"   2. Run: psql -f sql/03_populate_calendar.sql") 
    print(f"   3. Load data using sql/04_load_data.sql commands")
    print(f"   4. Create indexes: psql -f sql/02_create_indexes.sql")

if __name__ == "__main__":
    main()
