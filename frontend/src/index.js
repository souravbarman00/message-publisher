import React from 'react';
import ReactDOM from 'react-dom/client';
import MessagePublisher from './MessagePublisher';
import './index.css';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <MessagePublisher />
  </React.StrictMode>
);
