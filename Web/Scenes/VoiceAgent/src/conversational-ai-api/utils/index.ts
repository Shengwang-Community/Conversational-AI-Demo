// export const factoryFormatLog =
//   (options: { tag: string }) => (message: unknown) => {
//     return `[${options.tag}] ${JSON.stringify(message)}`
//   }
export const factoryFormatLog =
  (options: { tag: string }) =>
  (...args: unknown[]) => {
    return `[${options.tag}] ${args.map((arg) => JSON.stringify(arg)).join(' ')}`
  }
