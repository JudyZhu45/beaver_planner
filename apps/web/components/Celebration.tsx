'use client';

import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

interface CelebrationProps {
  isActive: boolean;
  onComplete?: () => void;
}

export default function Celebration({ isActive, onComplete }: CelebrationProps) {
  const [particles, setParticles] = useState<Array<{
    id: number;
    x: number;
    y: number;
    emoji: string;
    rotation: number;
    scale: number;
  }>>([]);

  useEffect(() => {
    if (isActive) {
      // Generate celebration particles
      const emojis = ['🎉', '✨', '🌟', '💫', '🦫', '🎊', '⭐'];
      const newParticles = Array.from({ length: 20 }, (_, i) => ({
        id: i,
        x: Math.random() * 100 - 50, // Random X spread
        y: Math.random() * -100 - 50, // Start above
        emoji: emojis[Math.floor(Math.random() * emojis.length)],
        rotation: Math.random() * 360,
        scale: 0.5 + Math.random() * 1
      }));
      setParticles(newParticles);

      // Auto cleanup after animation
      const timer = setTimeout(() => {
        setParticles([]);
        onComplete?.();
      }, 2000);

      return () => clearTimeout(timer);
    }
  }, [isActive, onComplete]);

  return (
    <AnimatePresence>
      {isActive && (
        <div className="pointer-events-none fixed inset-0 z-50 flex items-center justify-center overflow-hidden">
          {/* Center burst */}
          <motion.div
            initial={{ scale: 0, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0, opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="absolute text-6xl"
          >
            🎉
          </motion.div>

          {/* Floating particles */}
          {particles.map((particle) => (
            <motion.div
              key={particle.id}
              initial={{
                x: 0,
                y: 0,
                scale: 0,
                rotate: 0,
                opacity: 1
              }}
              animate={{
                x: particle.x * 3,
                y: particle.y * 2 + 200,
                scale: particle.scale,
                rotate: particle.rotation + 180,
                opacity: 0
              }}
              transition={{
                duration: 1.5 + Math.random() * 0.5,
                ease: [0.25, 0.46, 0.45, 0.94]
              }}
              className="absolute text-3xl"
            >
              {particle.emoji}
            </motion.div>
          ))}

          {/* Success message */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            transition={{ delay: 0.2, duration: 0.4 }}
            className="absolute mt-32 text-center"
          >
            <p className="text-lg font-semibold text-[#5B8C5A]">
              太棒了！又完成一个！
            </p>
            <p className="mt-1 text-sm text-[#8B7355]">
              海狸为你骄傲 🦫✨
            </p>
          </motion.div>

          {/* Background flash */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: [0, 0.3, 0] }}
            transition={{ duration: 0.5 }}
            className="absolute inset-0 bg-gradient-to-br from-[#D4A574]/30 via-transparent to-[#5B8C5A]/20"
          />
        </div>
      )}
    </AnimatePresence>
  );
}

// Simple hook for using celebration
export function useCelebration() {
  const [isCelebrating, setIsCelebrating] = useState(false);

  const celebrate = () => {
    setIsCelebrating(true);
  };

  const stopCelebration = () => {
    setIsCelebrating(false);
  };

  return { isCelebrating, celebrate, stopCelebration };
}
