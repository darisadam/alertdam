import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import App from './App'

describe('App', () => {
  it('renders the brand in the sidebar', () => {
    render(<App />)
    expect(screen.getByText('AlertDam')).toBeInTheDocument()
  })

  it('redirects / to the dashboard', () => {
    window.history.pushState({}, '', '/')
    render(<App />)
    expect(screen.getByRole('heading', { name: /dashboard/i })).toBeInTheDocument()
  })

  it('renders a nav entry for every top-level section', () => {
    render(<App />)
    const expected = [
      '/dashboard',
      '/incidents',
      '/schedules',
      '/policies',
      '/integrations',
      '/settings',
    ]
    const hrefs = screen.getAllByRole('link').map((a) => a.getAttribute('href'))
    expect(hrefs).toEqual(expected)
  })
})
