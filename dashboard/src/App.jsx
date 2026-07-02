import React from 'react'

export default function App() {
  return (
    <div style={{ display: 'flex', width: '100%' }}>
      {/* Sidebar Navigation */}
      <aside className="sidebar">
        <div>
          <div className="sidebar-brand">
            <div className="sidebar-logo"></div>
            <span style={{ fontWeight: 700, fontSize: 16, color: '#0f172a' }}>Agent GRC</span>
          </div>
          <nav>
            <ul className="sidebar-menu">
              <li>
                <a href="#overview" className="sidebar-item active">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                  </svg>
                  <span>Übersicht</span>
                </a>
              </li>
              <li>
                <a href="#agents" className="sidebar-item">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                  </svg>
                  <span>Agenten</span>
                </a>
              </li>
              <li>
                <a href="#consumption" className="sidebar-item">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                  </svg>
                  <span>Verbrauch</span>
                </a>
              </li>
              <li>
                <a href="#governance" className="sidebar-item">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                  <span>Governance</span>
                </a>
              </li>
              <li>
                <a href="#costs" className="sidebar-item">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <span>Kosten</span>
                </a>
              </li>
              <li>
                <a href="#actions" className="sidebar-item">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                  <span>Aktionen</span>
                </a>
              </li>
              <li>
                <a href="#reports" className="sidebar-item">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <span>Berichte</span>
                </a>
              </li>
            </ul>
          </nav>
        </div>
        <div className="sidebar-footer">
          <a href="#minimize" className="sidebar-item" style={{ paddingLeft: 8 }}>
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            <span>Menü minimieren</span>
          </a>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="app-container">
        {/* Top Header Controls */}
        <header style={{ backgroundColor: '#ffffff', borderBottom: '1px solid #e2e8f0', padding: '16px 24px' }}>
          <div className="top-header">
            <div className="header-title">
              <h1>Copilot & Agent Governance Dashboard</h1>
              <p>Exemplarische Übersicht für Verbrauch, Governance, Limits und Maßnahmen</p>
            </div>
            <div className="header-controls">
              <div className="search-container">
                <svg className="search-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <input type="text" className="search-input" placeholder="Suche nach Agenten, Ownern, Services..." />
              </div>
              <div className="date-picker">
                <svg style={{ width: 16, height: 16, color: '#64748b' }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <span>01.05.2025 – 31.05.2025</span>
              </div>
              <select className="env-select" defaultValue="Prod">
                <option value="Prod">Prod</option>
                <option value="Stage">Stage</option>
                <option value="Dev">Dev</option>
              </select>
              <button className="icon-button">
                <svg style={{ width: 20, height: 20 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
              </button>
              <div className="profile-avatar">AD</div>
            </div>
          </div>
        </header>

        {/* Dashboard Content & Side Panel */}
        <div className="dashboard-wrapper">
          <main className="main-content">
            {/* KPI Cards Row */}
            <section className="kpi-row">
              <div className="kpi-card">
                <div className="kpi-icon-wrapper blue">
                  <svg style={{ width: 22, height: 22 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                  </svg>
                </div>
                <div className="kpi-details">
                  <span className="kpi-label">Aktive Agenten</span>
                  <span className="kpi-value">24</span>
                  <span className="kpi-trend up">
                    <svg style={{ width: 10, height: 10 }} xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fillRule="evenodd" d="M12 3.293V17a1 1 0 11-2 0V3.293L4.707 8.586a1 1 0 01-1.414-1.414l7-7a1 1 0 011.414 0l7 7a1 1 0 01-1.414 1.414L12 3.293z" clipRule="evenodd" />
                    </svg>
                    <span>3 vs. Vormonat</span>
                  </span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-icon-wrapper cyan">
                  <svg style={{ width: 22, height: 22 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                  </svg>
                </div>
                <div className="kpi-details">
                  <span className="kpi-label">Monatsverbrauch</span>
                  <span className="kpi-value">18.420 Credits</span>
                  <span className="kpi-trend up">
                    <svg style={{ width: 10, height: 10 }} xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fillRule="evenodd" d="M12 3.293V17a1 1 0 11-2 0V3.293L4.707 8.586a1 1 0 01-1.414-1.414l7-7a1 1 0 011.414 0l7 7a1 1 0 01-1.414 1.414L12 3.293z" clipRule="evenodd" />
                    </svg>
                    <span>16 % vs. Vormonat</span>
                  </span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-icon-wrapper green">
                  <svg style={{ width: 22, height: 22 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z" />
                  </svg>
                </div>
                <div className="kpi-details">
                  <span className="kpi-label">Budgetstatus</span>
                  <span className="kpi-value">72 %</span>
                  <span className="kpi-trend">
                    <span>2.880 € von 4.000 €</span>
                  </span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-icon-wrapper orange">
                  <svg style={{ width: 22, height: 22 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                </div>
                <div className="kpi-details">
                  <span className="kpi-label">Agents mit Risiko</span>
                  <span className="kpi-value">5</span>
                  <span className="kpi-trend up">
                    <svg style={{ width: 10, height: 10 }} xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fillRule="evenodd" d="M12 3.293V17a1 1 0 11-2 0V3.293L4.707 8.586a1 1 0 01-1.414-1.414l7-7a1 1 0 011.414 0l7 7a1 1 0 01-1.414 1.414L12 3.293z" clipRule="evenodd" />
                    </svg>
                    <span>1 vs. Vormonat</span>
                  </span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-icon-wrapper red">
                  <svg style={{ width: 22, height: 22 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                </div>
                <div className="kpi-details">
                  <span className="kpi-label">Sofortmaßnahmen</span>
                  <span className="kpi-value">3</span>
                  <span className="kpi-trend" style={{ color: '#dc2626', fontWeight: 600 }}>
                    <span>Erfordern Aufmerksamkeit</span>
                  </span>
                </div>
              </div>
            </section>

            {/* Grid of Blocks */}
            <section className="content-grid">
              {/* Block 1: 1. Agent 365 – Registry & Governance */}
              <div className="grid-block">
                <div>
                  <div className="block-header">
                    <span className="block-title">
                      <svg style={{ width: 16, height: 16, color: '#4f46e5' }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                      </svg>
                      1. Agent 365 – Registry & Governance
                    </span>
                    <button className="block-header-button">
                      <span>Prüfbericht</span>
                      <svg style={{ width: 12, height: 12 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                  <div className="block-table-wrapper">
                    <table className="block-table">
                      <thead>
                        <tr>
                          <th>Agent</th>
                          <th>Owner</th>
                          <th>Status</th>
                          <th>Risiko</th>
                          <th>Aktion</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td><strong>HR Onboarding Copilot</strong></td>
                          <td>HR</td>
                          <td><span className="badge green">Aktiv</span></td>
                          <td><span className="badge warning">Mittel</span></td>
                          <td><button className="btn-action blue">Prüfen</button></td>
                        </tr>
                        <tr>
                          <td><strong>Sales Proposal Agent</strong></td>
                          <td>Vertrieb</td>
                          <td><span className="badge green">Aktiv</span></td>
                          <td><span className="badge green">Niedrig</span></td>
                          <td><button className="btn-action blue">Limit setzen</button></td>
                        </tr>
                        <tr>
                          <td><strong>IT Helpdesk Agent</strong></td>
                          <td>IT</td>
                          <td><span className="badge green">Aktiv</span></td>
                          <td><span className="badge warning">Mittel</span></td>
                          <td><button className="btn-action red">Stoppen</button></td>
                        </tr>
                        <tr>
                          <td><strong>Finance Report Agent</strong></td>
                          <td>Finance</td>
                          <td><span className="badge warning">Review fällig</span></td>
                          <td><span className="badge critical">Hoch</span></td>
                          <td><button className="btn-action solid-red">Blockieren</button></td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
                <div className="block-footer">
                  <div className="footer-card-grid">
                    <div className="footer-card">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                      </svg>
                      <div>Owner zugewiesen <span className="highlight">22/24</span></div>
                    </div>
                    <div className="footer-card">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      </svg>
                      <div>Shadow Agents <span className="highlight">2</span></div>
                    </div>
                    <div className="footer-card">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                      </svg>
                      <div>Reviews fällig <span className="highlight">4</span></div>
                    </div>
                    <div className="footer-card">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
                      </svg>
                      <div>Health-Score <span className="highlight">81</span></div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Block 2: 2. Copilot Studio Analytics */}
              <div className="grid-block">
                <div>
                  <div className="block-header">
                    <span className="block-title">
                      <svg style={{ width: 16, height: 16, color: '#4f46e5' }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 12l3-3 3 3 4-4M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
                      </svg>
                      2. Copilot Studio Analytics
                    </span>
                    <button className="block-header-button">
                      <span>Analytics öffnen</span>
                      <svg style={{ width: 12, height: 12 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                  <div className="block-table-wrapper">
                    <table className="block-table">
                      <thead>
                        <tr>
                          <th>Agent</th>
                          <th>Verbrauch (Monat)</th>
                          <th>Trend</th>
                          <th>Aktion</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td><strong>HR Onboarding Copilot</strong></td>
                          <td>2.140 Credits</td>
                          <td style={{ color: '#16a34a', fontWeight: 600 }}>↑ +12 %</td>
                          <td><button className="btn-action blue">Analyse</button></td>
                        </tr>
                        <tr>
                          <td><strong>Sales Proposal Agent</strong></td>
                          <td>4.320 Credits</td>
                          <td style={{ color: '#16a34a', fontWeight: 600 }}>↑ +28 %</td>
                          <td><button className="btn-action blue">Limit setzen</button></td>
                        </tr>
                        <tr>
                          <td><strong>IT Helpdesk Agent</strong></td>
                          <td>5.980 Credits</td>
                          <td style={{ color: '#16a34a', fontWeight: 600 }}>↑ +7 %</td>
                          <td><button className="btn-action blue">Optimieren</button></td>
                        </tr>
                        <tr>
                          <td><strong>Finance Report Agent</strong></td>
                          <td>1.860 Credits</td>
                          <td style={{ color: '#16a34a', fontWeight: 600 }}>↑ +41 %</td>
                          <td><button className="btn-action blue">Prüfen</button></td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
                <div className="block-footer">
                  <div className="footer-buttons">
                    <button className="btn-footer">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                      <span>Top-Verbraucher</span>
                    </button>
                    <button className="btn-footer">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 12l3-3 3 3 4-4M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
                      </svg>
                      <span>Billing Trend</span>
                    </button>
                    <button className="btn-footer">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z" />
                      </svg>
                      <span>Kostenverteilung</span>
                    </button>
                    <button className="btn-footer">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
                      </svg>
                      <span>Generative Nutzung</span>
                    </button>
                  </div>
                </div>
              </div>

              {/* Block 3: 3. Power Platform Admin Center – Limits */}
              <div className="grid-block">
                <div>
                  <div className="block-header">
                    <span className="block-title">
                      <svg style={{ width: 16, height: 16, color: '#4f46e5' }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
                      </svg>
                      3. Power Platform Admin Center – Limits
                    </span>
                    <button className="block-header-button">
                      <span>Limits verwalten</span>
                      <svg style={{ width: 12, height: 12 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                  <div className="block-table-wrapper">
                    <table className="block-table">
                      <thead>
                        <tr>
                          <th>Agent</th>
                          <th>Monatliches Limit (Credits)</th>
                          <th>Status</th>
                          <th>Aktion</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td><strong>HR Onboarding Copilot</strong></td>
                          <td>3.000</td>
                          <td><span className="badge green">Innerhalb Limit</span></td>
                          <td><button className="btn-action blue">Anpassen</button></td>
                        </tr>
                        <tr>
                          <td><strong>Sales Proposal Agent</strong></td>
                          <td>4.500</td>
                          <td><span className="badge warning">Nahe Limit</span></td>
                          <td><button className="btn-action blue" style={{ color: '#d97706', borderColor: '#fde68a' }}>Warnung</button></td>
                        </tr>
                        <tr>
                          <td><strong>IT Helpdesk Agent</strong></td>
                          <td>6.500</td>
                          <td><span className="badge green">Innerhalb Limit</span></td>
                          <td><button className="btn-action blue">Anpassen</button></td>
                        </tr>
                        <tr>
                          <td><strong>Finance Report Agent</strong></td>
                          <td>2.000</td>
                          <td><span className="badge critical">Über Limit</span></td>
                          <td><button className="btn-action red">Stoppen</button></td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
                <div className="block-footer">
                  <span className="footer-text">
                    <svg style={{ width: 14, height: 14 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Monatliche Credit-Limits je Agent
                  </span>
                </div>
              </div>

              {/* Block 4: 4. M365 Admin Center – Billing Policies */}
              <div className="grid-block">
                <div>
                  <div className="block-header">
                    <span className="block-title">
                      <svg style={{ width: 16, height: 16, color: '#4f46e5' }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
                      </svg>
                      4. M365 Admin Center – Billing Policies
                    </span>
                    <button className="block-header-button">
                      <span>Richtlinien verwalten</span>
                      <svg style={{ width: 12, height: 12 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                  <div className="block-table-wrapper">
                    <table className="block-table">
                      <thead>
                        <tr>
                          <th>Gruppe / Policy</th>
                          <th>Service</th>
                          <th>Budget</th>
                          <th>Aktion</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td><strong>Pilotgruppe Vertrieb</strong></td>
                          <td>M365 Copilot Chat</td>
                          <td>2.000 €</td>
                          <td><button className="btn-action blue">Prüfen</button></td>
                        </tr>
                        <tr>
                          <td><strong>SharePoint Agents</strong></td>
                          <td>SharePoint Agent</td>
                          <td>1.200 €</td>
                          <td><button className="btn-action blue">Bearbeiten</button></td>
                        </tr>
                        <tr>
                          <td><strong>Retrieval API Team</strong></td>
                          <td>Copilot Retrieval API</td>
                          <td>850 €</td>
                          <td><button className="btn-action blue" style={{ color: '#d97706', borderColor: '#fde68a' }}>Warnung</button></td>
                        </tr>
                        <tr>
                          <td><strong>Externe Fachanwender</strong></td>
                          <td>Metered Agents</td>
                          <td>500 €</td>
                          <td><button className="btn-action red">Blockieren</button></td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
                <div className="block-footer">
                  <span className="footer-text">
                    <svg style={{ width: 14, height: 14 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Budget = Warnung, keine harte Sperre
                  </span>
                </div>
              </div>

              {/* Block 5: 5. Azure Cost Management / BYO Models */}
              <div className="grid-block">
                <div>
                  <div className="block-header">
                    <span className="block-title">
                      <svg style={{ width: 16, height: 16, color: '#4f46e5' }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                      </svg>
                      5. Azure Cost Management / BYO Models
                    </span>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="block-header-button" style={{ color: '#ea580c', borderColor: '#ffedd5', backgroundColor: '#fff7ed' }}>
                        <span>Token-basierte Kosten</span>
                      </button>
                      <button className="block-header-button">
                        <span>Details öffnen</span>
                        <svg style={{ width: 12, height: 12 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                        </svg>
                      </button>
                    </div>
                  </div>
                  <div className="block-table-wrapper">
                    <table className="block-table">
                      <thead>
                        <tr>
                          <th>Model / Service</th>
                          <th>Verbrauch (Monat)</th>
                          <th>Kosten</th>
                          <th>Aktion</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td><strong>Azure OpenAI GPT-4.1</strong></td>
                          <td>1,9 Mio Tokens</td>
                          <td style={{ fontWeight: 600 }}>420 €</td>
                          <td><button className="btn-action blue" style={{ color: '#d97706', borderColor: '#fde68a' }}>Drosseln</button></td>
                        </tr>
                        <tr>
                          <td><strong>Azure AI Foundry RAG</strong></td>
                          <td>860 Tsd Tokens</td>
                          <td style={{ fontWeight: 600 }}>155 €</td>
                          <td><button className="btn-action blue">Prüfen</button></td>
                        </tr>
                        <tr>
                          <td><strong>Premium Reasoning Model</strong></td>
                          <td>540 Tsd Tokens</td>
                          <td style={{ fontWeight: 600 }}>210 €</td>
                          <td><button className="btn-action red">Beschränken</button></td>
                        </tr>
                        <tr>
                          <td><strong>Embeddings Service</strong></td>
                          <td>2,3 Mio Tokens</td>
                          <td style={{ fontWeight: 600 }}>88 €</td>
                          <td><button className="btn-action blue">Optimieren</button></td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
                <div className="block-footer">
                  <span className="footer-text">
                    <svg style={{ width: 14, height: 14 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Token-basierte Kosten können je nach Nutzung stark variieren.
                  </span>
                </div>
              </div>

              {/* Block 6: 6. KPI / UPI Reporting */}
              <div className="grid-block">
                <div>
                  <div className="block-header">
                    <span className="block-title">
                      <svg style={{ width: 16, height: 16, color: '#4f46e5' }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 022 2h2a2 2 0 022-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                      </svg>
                      6. KPI / UPI Reporting
                    </span>
                    <button className="block-header-button">
                      <span>KPI-Bericht öffnen</span>
                      <svg style={{ width: 12, height: 12 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                  <div className="block-table-wrapper">
                    <table className="block-table">
                      <thead>
                        <tr>
                          <th>Metrik</th>
                          <th>Wert</th>
                          <th>Ziel</th>
                          <th>Trend (30 Tage)</th>
                          <th>Status</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td><strong>Active Usage Rate</strong></td>
                          <td>74 %</td>
                          <td>70 %</td>
                          <td>
                            <div className="sparkline-container">
                              <svg className="sparkline-svg" viewBox="0 0 100 30">
                                <path d="M0,20 Q15,10 30,22 T60,5 T90,15" />
                              </svg>
                            </div>
                          </td>
                          <td><span className="badge green">Gut</span></td>
                        </tr>
                        <tr>
                          <td><strong>Repeat Usage Rate</strong></td>
                          <td>61 %</td>
                          <td>60 %</td>
                          <td>
                            <div className="sparkline-container">
                              <svg className="sparkline-svg" viewBox="0 0 100 30">
                                <path d="M0,25 Q15,15 30,20 T60,18 T90,10" />
                              </svg>
                            </div>
                          </td>
                          <td><span className="badge green">Gut</span></td>
                        </tr>
                        <tr>
                          <td><strong>Prompt Success Rate</strong></td>
                          <td>78 %</td>
                          <td>75 %</td>
                          <td>
                            <div className="sparkline-container">
                              <svg className="sparkline-svg" viewBox="0 0 100 30">
                                <path d="M0,18 Q15,22 30,12 T60,25 T90,8" />
                              </svg>
                            </div>
                          </td>
                          <td><span className="badge green">Gut</span></td>
                        </tr>
                        <tr>
                          <td><strong>Time Saved per User</strong></td>
                          <td>2,3 Std/Woche</td>
                          <td>2 Std</td>
                          <td>
                            <div className="sparkline-container">
                              <svg className="sparkline-svg" viewBox="0 0 100 30">
                                <path d="M0,22 Q15,18 30,25 T60,10 T90,12" />
                              </svg>
                            </div>
                          </td>
                          <td><span className="badge green">Gut</span></td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
                <div className="block-footer">
                  <div className="footer-buttons">
                    <button className="btn-footer">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                      </svg>
                      <span>Bericht exportieren</span>
                    </button>
                    <button className="btn-footer">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <span>Owner erinnern</span>
                    </button>
                    <button className="btn-footer" style={{ color: '#dc2626' }}>
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
                      </svg>
                      <span>Agent sperren</span>
                    </button>
                    <button className="btn-footer primary">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                      </svg>
                      <span>Review starten</span>
                    </button>
                  </div>
                </div>
              </div>
            </section>
          </main>

          {/* Right measures panel */}
          <aside className="measures-panel">
            <div className="measures-header">
              <span className="measures-title">Sofortmaßnahmen</span>
              <span className="count-badge">3</span>
            </div>

            <div className="measure-card">
              <div className="measure-card-header">
                <div className="measure-number-bubble red">1</div>
                <div className="measure-text">Finance Report Agent blockieren – Limit überschritten</div>
                <div className="measure-card-arrow">
                  <svg style={{ width: 14, height: 14 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              </div>
              <div className="measure-card-footer">
                <span className="badge red" style={{ fontSize: 9 }}>Kritisch</span>
                <span className="measure-time">
                  <svg style={{ width: 12, height: 12 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Vor 15 Min.
                </span>
              </div>
            </div>

            <div className="measure-card">
              <div className="measure-card-header">
                <div className="measure-number-bubble orange">2</div>
                <div className="measure-text">Sales Proposal Agent prüfen – hoher Verbrauchstrend</div>
                <div className="measure-card-arrow">
                  <svg style={{ width: 14, height: 14 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              </div>
              <div className="measure-card-footer">
                <span className="badge orange" style={{ fontSize: 9 }}>Warnung</span>
                <span className="measure-time">
                  <svg style={{ width: 12, height: 12 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Vor 32 Min.
                </span>
              </div>
            </div>

            <div className="measure-card">
              <div className="measure-card-header">
                <div className="measure-number-bubble yellow">3</div>
                <div className="measure-text">Shadow Agent identifiziert – Owner zuweisen</div>
                <div className="measure-card-arrow">
                  <svg style={{ width: 14, height: 14 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              </div>
              <div className="measure-card-footer">
                <span className="badge warning" style={{ fontSize: 9, backgroundColor: '#fef9c3', color: '#854d0e' }}>Hinweis</span>
                <span className="measure-time">
                  <svg style={{ width: 12, height: 12 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Vor 1 Std.
                </span>
              </div>
            </div>

            <div className="measure-card">
              <div className="measure-card-header">
                <div className="measure-number-bubble green">4</div>
                <div className="measure-text">BYO Model drosseln – Tokenkosten steigen</div>
                <div className="measure-card-arrow">
                  <svg style={{ width: 14, height: 14 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              </div>
              <div className="measure-card-footer">
                <span className="badge green" style={{ fontSize: 9 }}>Hinweis</span>
                <span className="measure-time">
                  <svg style={{ width: 12, height: 12 }} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Vor 2 Std.
                </span>
              </div>
            </div>

            <a href="#all-measures" className="measure-link-all">
              Alle Maßnahmen anzeigen &gt;
            </a>
          </aside>
        </div>
      </div>
    </div>
  )
}
