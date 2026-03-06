'use client'

import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { toast } from 'sonner'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { profileSchema } from '@/lib/utils/validators'
import type { z } from 'zod'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Separator } from '@/components/ui/separator'

type ProfileFormValues = z.infer<typeof profileSchema>

export default function ProfilePage() {
  const router = useRouter()
  const [loading, setLoading] = useState(true)
  const [email, setEmail] = useState('')

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<ProfileFormValues>({
    resolver: zodResolver(profileSchema),
  })

  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      setEmail(user.email ?? '')

      const { data: profile } = await supabase
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .single()

      if (profile) {
        reset({ full_name: profile.full_name ?? '' })
      }
      setLoading(false)
    }
    load()
  }, [reset])

  async function onSubmit(values: ProfileFormValues) {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    const { error } = await supabase
      .from('profiles')
      .update({ full_name: values.full_name })
      .eq('id', user.id)

    if (error) {
      toast.error('Failed to update profile')
      return
    }

    toast.success('Profile updated')
    router.refresh()
  }

  if (loading) {
    return <div className="text-sm text-muted-foreground">Loading...</div>
  }

  return (
    <div className="space-y-6 max-w-lg">
      <div>
        <h1 className="text-2xl font-bold">Profile</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Update your account information.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Account</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-1 mb-4">
            <Label className="text-muted-foreground">Email</Label>
            <p className="text-sm">{email}</p>
          </div>
          <Separator />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Personal Info</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="full_name">Full name</Label>
              <Input id="full_name" placeholder="Your name" {...register('full_name')} />
              {errors.full_name && (
                <p className="text-xs text-destructive">{errors.full_name.message}</p>
              )}
            </div>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? 'Saving...' : 'Save changes'}
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
