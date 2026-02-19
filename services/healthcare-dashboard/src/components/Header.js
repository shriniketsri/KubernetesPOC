import React from 'react';
import { AppBar, Toolbar, Typography, Box } from '@mui/material';
import { LocalHospital } from '@mui/icons-material';

const Header = () => {
  return (
    <AppBar position="fixed" sx={{ zIndex: (theme) => theme.zIndex.drawer + 1 }}>
      <Toolbar>
        <LocalHospital sx={{ mr: 2 }} />
        <Typography variant="h6" noWrap component="div" sx={{ flexGrow: 1 }}>
          Healthcare Microservices Dashboard
        </Typography>
        <Box sx={{ display: 'flex', alignItems: 'center' }}>
          <Typography variant="body2" sx={{ mr: 2 }}>
            Kubernetes + Istio + React
          </Typography>
        </Box>
      </Toolbar>
    </AppBar>
  );
};

export default Header;