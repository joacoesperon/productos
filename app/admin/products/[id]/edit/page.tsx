import { notFound } from 'next/navigation'
import Link from 'next/link'
import { ChevronLeft } from 'lucide-react'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import ProductForm from '@/components/admin/ProductForm'
import type { ProductFormValues } from '@/lib/utils/validators'

export default async function EditProductPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const supabase = await createClient()

  const { data: product } = await supabase
    .from('products')
    .select('*')
    .eq('id', id)
    .single()

  if (!product) notFound()

  async function updateProduct(values: ProductFormValues): Promise<{ error?: string }> {
    'use server'
    const adminClient = createAdminClient()
    const thumbnailUrl = values.thumbnail_url === '' ? null : values.thumbnail_url

    const { error } = await adminClient
      .from('products')
      .update({
        name: values.name,
        slug: values.slug,
        description: values.description ?? null,
        short_description: values.short_description ?? null,
        type: values.type,
        status: values.status,
        thumbnail_url: thumbnailUrl ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)

    if (error) {
      if (error.code === '23505') {
        return { error: 'Ya existe un producto con ese slug' }
      }
      return { error: error.message }
    }

    return {}
  }

  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <Link
          href="/admin/products"
          className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground mb-4"
        >
          <ChevronLeft className="h-4 w-4" />
          Volver a productos
        </Link>
        <h1 className="text-2xl font-bold">Editar producto</h1>
        <p className="text-muted-foreground text-sm">{product.name}</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Información del producto</CardTitle>
        </CardHeader>
        <CardContent>
          <ProductForm product={product} onSubmit={updateProduct} />
        </CardContent>
      </Card>
    </div>
  )
}
