/* eslint-disable @typescript-eslint/no-empty-object-type */
import { buildZodFieldConfig } from '@autoform/react'
import type { FieldTypes } from './AutoForm'

export const fieldConfig = buildZodFieldConfig<
  FieldTypes,
  {
    // Add types for `customData` here.
  }
>()
