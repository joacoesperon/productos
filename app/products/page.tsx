import { createServiceClient } from '@/lib/supabase/server'
import ProductCard from '@/components/store/ProductCard'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import type { Product, LicensePlan, ProductType } from '@/types'
import { PRODUCT_TYPE_LABELS } from '@/types'

type ProductWithPlans = Product & { license_plans: LicensePlan[] }

const ALL_TYPES: ProductType[] = ['software', 'ebook', 'course', 'template']

interface SearchParams {
  type?: string
}

export default async function ProductsPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>
}) {
  const { type } = await searchParams
  const supabase = createServiceClient()

  let query = supabase
    .from('products')
    .select('*, license_plans(*)')
    .eq('status', 'published')
    .order('created_at', { ascending: false })

  if (type && ALL_TYPES.includes(type as ProductType)) {
    query = query.eq('type', type as ProductType)
  }

  const { data: products } = await query
  const items = (products ?? []) as ProductWithPlans[]

  return (
    <div className="container mx-auto px-4 py-10">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Products</h1>
        <p className="text-muted-foreground">Browse all available digital products and license plans.</p>
      </div>

      {/* Type filter */}
      <div className="mb-8">
        <Tabs defaultValue={type ?? 'all'}>
          <TabsList>
            <TabsTrigger value="all" asChild>
              <a href="/products">All</a>
            </TabsTrigger>
            {ALL_TYPES.map((t) => (
              <TabsTrigger key={t} value={t} asChild>
                <a href={`/products?type=${t}`}>{PRODUCT_TYPE_LABELS[t]}</a>
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
      </div>

      {items.length === 0 ? (
        <div className="text-center py-20 text-muted-foreground">
          <p className="text-lg">No products found.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {items.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      )}
    </div>
  )
}
